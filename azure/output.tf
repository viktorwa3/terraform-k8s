output "resource_group" {
  description = "Resource group holding everything"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

output "tenant_id" {
  description = "Entra tenant id"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Azure subscription id"
  value       = data.azurerm_client_config.current.subscription_id
}

output "cluster_name" {
  description = "Cluster name (Arc resource name)"
  value       = local.cluster_name
}

output "cp" {
  description = "Control plane node"
  value = {
    name       = azurerm_linux_virtual_machine.node["${var.app_name}-cp-0"].name
    public_ip  = azurerm_public_ip.node["${var.app_name}-cp-0"].ip_address
    private_ip = azurerm_network_interface.node["${var.app_name}-cp-0"].private_ip_address
  }
}

output "workers" {
  description = "Worker nodes"
  value = [for i in range(var.worker_count) : {
    name       = azurerm_linux_virtual_machine.node["${var.app_name}-worker-${i}"].name
    public_ip  = azurerm_public_ip.node["${var.app_name}-worker-${i}"].ip_address
    private_ip = azurerm_network_interface.node["${var.app_name}-worker-${i}"].private_ip_address
  }]
}

output "ingress_fqdn" {
  description = "DNS name of the load balancer in front of ingress-nginx"
  value       = azurerm_public_ip.lb.fqdn
}

output "key_vault_name" {
  description = "Key Vault with the Argo CD admin password"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "node_identity_client_id" {
  description = "Client id of the identity attached to all nodes"
  value       = azurerm_user_assigned_identity.node.client_id
}

output "log_analytics_workspace_id" {
  description = "ARM id of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}
