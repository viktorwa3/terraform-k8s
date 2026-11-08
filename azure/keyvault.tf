locals {
  # Vault names are <= 24 chars.
  key_vault_name = "kv-tk-${random_string.suffix.result}"
}

resource "azurerm_key_vault" "main" {
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = local.default_tags
}

# CI writes the secret below.
resource "azurerm_role_assignment" "ci_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "ServicePrincipal"
}

# Survives RG rebuilds without manual grants.
resource "azurerm_role_assignment" "secret_readers" {
  for_each = toset(var.secret_reader_object_ids)

  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
  principal_type       = "User"
}

# New role assignments take a while to apply; the secret write fails with 403 before.
resource "time_sleep" "rbac_propagation" {
  create_duration = "60s"

  triggers = {
    role_assignment = azurerm_role_assignment.ci_secrets_officer.id
    key_vault       = azurerm_key_vault.main.id
  }

  depends_on = [azurerm_role_assignment.ci_secrets_officer]
}

# Generated during apply, never stored in plan or state; bump the version to rotate.
ephemeral "random_password" "argocd_admin" {
  length  = 24
  special = false
}

resource "azurerm_key_vault_secret" "argocd_admin_password" {
  name             = "argocd-admin-password"
  key_vault_id     = azurerm_key_vault.main.id
  value_wo         = ephemeral.random_password.argocd_admin.result
  value_wo_version = 1
  content_type     = "Argo CD admin password, consumed by External Secrets"
  tags             = local.default_tags

  depends_on = [time_sleep.rbac_propagation]
}
