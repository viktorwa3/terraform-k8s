# One identity for all nodes until workload identity exists; used by ESO and Arc onboarding.
resource "azurerm_user_assigned_identity" "node" {
  name                = "id-${var.app_name}-node"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.default_tags
}

resource "azurerm_role_assignment" "node_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.node.principal_id
  principal_type       = "ServicePrincipal"
}

# Arc onboarding and extensions run from the control plane.
resource "azurerm_role_assignment" "node_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.node.principal_id
  principal_type       = "ServicePrincipal"
}
