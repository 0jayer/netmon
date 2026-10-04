resource "azurerm_user_assigned_identity" "grafana" {
  name                = "${var.project}-grafana-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "grafana" {
  name                      = "grafana-fic"
  user_assigned_identity_id = azurerm_user_assigned_identity.grafana.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                   = "system:serviceaccount:monitoring:kps-grafana"
}

resource "azurerm_role_assignment" "grafana_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.grafana.principal_id
}

data "azurerm_user_assigned_identity" "ci" {
  name                = "netmon-ci-identity"
  resource_group_name = "netmon-persist-rg"
}

resource "azurerm_role_assignment" "ci_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_user_assigned_identity.ci.principal_id
}