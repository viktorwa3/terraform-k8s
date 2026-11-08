provider "azurerm" {
  use_oidc = true

  # Providers are registered once outside Terraform.
  resource_provider_registrations = "none"

  features {
    # RG is deleted often: recover or drop soft-deleted resources instead of failing.
    key_vault {
      recover_soft_deleted_key_vaults = true
      purge_soft_delete_on_destroy    = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  default_tags = {
    Application = var.app_name
    Environment = var.environment
  }

  cluster_name = "${var.app_name}-azure"

  # Name is the Ansible inventory hostname; Role drives its groups.
  nodes = merge(
    { "${var.app_name}-cp-0" = "control-plane" },
    { for i in range(var.worker_count) : "${var.app_name}-worker-${i}" => "worker" }
  )

  # Same ansible user and SSH key as AWS.
  cloud_config = "${path.module}/../aws/cloud-config.yaml"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.app_name}"
  location = var.location
  tags     = local.default_tags
}

# Vault and workspace names stay reserved after a manual RG delete: new suffix per RG incarnation.
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false

  keepers = {
    resource_group = azurerm_resource_group.main.id
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.default_tags
}

resource "azurerm_subnet" "cluster" {
  name                 = "snet-cluster"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Node-to-node traffic is allowed by the default AllowVnetInBound rule.
resource "azurerm_network_security_group" "cluster" {
  name                = "nsg-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.default_tags

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*" # public GitHub runners
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_ranges    = ["80", "443", "30080", "30443"]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "cluster" {
  subnet_id                 = azurerm_subnet.cluster.id
  network_security_group_id = azurerm_network_security_group.cluster.id
}

# No cloud-controller-manager, so the LB forwards 80/443 to the ingress-nginx NodePorts.
resource "azurerm_public_ip" "lb" {
  name                = "pip-${var.app_name}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.ingress_dns_label
  tags                = local.default_tags
}

resource "azurerm_lb" "main" {
  name                = "lb-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = local.default_tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "nodes" {
  name            = "nodes"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_lb_probe" "ingress" {
  for_each = { http = 30080, https = 30443 }

  name            = each.key
  loadbalancer_id = azurerm_lb.main.id
  protocol        = "Tcp"
  port            = each.value
}

resource "azurerm_lb_rule" "ingress" {
  for_each = {
    http  = { frontend = 80, backend = 30080 }
    https = { frontend = 443, backend = 30443 }
  }

  name                           = each.key
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = each.value.frontend
  backend_port                   = each.value.backend
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nodes.id]
  probe_id                       = azurerm_lb_probe.ingress[each.key].id
}

resource "azurerm_public_ip" "node" {
  for_each = local.nodes

  name                = "pip-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags
}

resource "azurerm_network_interface" "node" {
  for_each = local.nodes

  name                = "nic-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.default_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cluster.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.node[each.key].id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "node" {
  for_each = local.nodes

  network_interface_id    = azurerm_network_interface.node[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.nodes.id
}

resource "azurerm_linux_virtual_machine" "node" {
  for_each = local.nodes

  name                  = each.key
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.vm_size
  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  # Azure requires an admin user; the ansible user comes from cloud-init.
  admin_username                  = "azureadmin"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureadmin"
    public_key = yamldecode(file(local.cloud_config)).users[0].ssh_authorized_keys[0]
  }

  custom_data = base64encode(file(local.cloud_config))

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.node.id]
  }

  tags = merge(local.default_tags, {
    Name = each.key
    Role = each.value
  })
}
