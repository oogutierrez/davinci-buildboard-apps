resource "azurerm_container_app_environment" "env" {
  name                               = var.environment_name
  resource_group_name                = var.resource_group_name
  location                           = var.location
  infrastructure_subnet_id           = var.infrastructure_subnet_id
  internal_load_balancer_enabled     = var.internal_load_balancer_enabled
  infrastructure_resource_group_name = "ME_${var.environment_name}_${var.resource_group_name}_${var.location}"
  log_analytics_workspace_id         = var.log_analytics_workspace_id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    # Do NOT set min/max count for Consumption
  }
  tags = var.tags
}

# Private DNS zone for the Container App Environment
resource "azurerm_private_dns_zone" "cae_dns" {
  name                = azurerm_container_app_environment.env.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "cae_dns_link" {
  name                  = "dns-link-${var.environment_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cae_dns.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# Wildcard A record for all apps in the environment
resource "azurerm_private_dns_a_record" "cae_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.cae_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.env.static_ip_address]
}

# Private endpoint for the Container App Environment
resource "azurerm_private_endpoint" "cae_pe" {
  count = var.create_private_endpoint ? 1 : 0

  name                = var.private_endpoint_name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.private_endpoint_name}-n8n"
    private_connection_resource_id = azurerm_container_app_environment.env.id
    is_manual_connection           = false
    subresource_names              = ["managedEnvironments"]
  }

  private_dns_zone_group {
    name                 = "env-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.cae_dns.id]
  }

  tags = var.tags

  depends_on = [
    azurerm_container_app_environment.env,
    azurerm_private_dns_zone.cae_dns,
    azurerm_private_dns_zone_virtual_network_link.cae_dns_link
  ]
}


