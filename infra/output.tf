output "grafana_identity_client_id" {
  value = azurerm_user_assigned_identity.grafana.client_id
}

output "pg_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}