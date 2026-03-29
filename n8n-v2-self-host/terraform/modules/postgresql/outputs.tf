output "server_id" {
  description = "PostgreSQL server ID"
  value       = azurerm_postgresql_flexible_server.postgres.id
}

output "server_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "database_id" {
  description = "Database ID"
  value       = azurerm_postgresql_flexible_server_database.database.id
}

output "database_name" {
  description = "Database name"
  value       = azurerm_postgresql_flexible_server_database.database.name
}
