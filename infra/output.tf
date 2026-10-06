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
output "office_vm_ips" {
  value = azurerm_network_interface.office[*].private_ip_address
}

# Rendered into k8s/office_scrape.yaml, e.g. "10.0.3.10:9100","10.0.3.11:9100"
output "office_scrape_targets" {
  value = join(",", [for nic in azurerm_network_interface.office : "\"${nic.private_ip_address}:9100\""])
}
