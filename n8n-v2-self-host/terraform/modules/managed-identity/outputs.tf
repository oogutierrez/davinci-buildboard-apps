output "id" {
  description = "User-assigned managed identity ID"
  value       = azurerm_user_assigned_identity.identity.id
}

output "principal_id" {
  description = "User-assigned managed identity principal ID"
  value       = azurerm_user_assigned_identity.identity.principal_id
  sensitive   = true
}

output "client_id" {
  description = "User-assigned managed identity client ID"
  value       = azurerm_user_assigned_identity.identity.client_id
  sensitive   = true
}

output "name" {
  description = "User-assigned managed identity name"
  value       = azurerm_user_assigned_identity.identity.name
}
