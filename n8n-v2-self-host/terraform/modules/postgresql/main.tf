resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.postgres_version
  administrator_login           = var.admin_username
  administrator_password        = var.admin_password
  storage_mb                    = var.storage_mb
  sku_name                      = var.sku_name
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  public_network_access_enabled = false
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  zone                          = var.zone

  tags = var.tags

  lifecycle {
    #prevent_destroy       = var.prevent_destroy
    ignore_changes        = [administrator_password]
    create_before_destroy = false
  }
}

resource "azurerm_postgresql_flexible_server_database" "database" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = var.database_charset
  collation = var.database_collation
}

resource "azurerm_role_assignment" "postgres_reader" {
  scope                = azurerm_postgresql_flexible_server.postgres.id
  role_definition_name = "Reader"
  principal_id         = var.managed_identity_principal_id
}
