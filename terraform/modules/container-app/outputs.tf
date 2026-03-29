output "id" {
  description = "Container App ID"
  value       = azurerm_container_app.app.id
}

output "name" {
  description = "Container App name"
  value       = azurerm_container_app.app.name
}

output "latest_revision_fqdn" {
  description = "FQDN of the latest revision"
  value       = azurerm_container_app.app.latest_revision_fqdn
}

output "latest_revision_name" {
  description = "Name of the latest revision"
  value       = azurerm_container_app.app.latest_revision_name
}
