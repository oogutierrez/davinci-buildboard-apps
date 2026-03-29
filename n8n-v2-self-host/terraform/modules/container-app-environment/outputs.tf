output "id" {
  description = "Container App Environment ID"
  value       = azurerm_container_app_environment.env.id
}

output "name" {
  description = "Container App Environment name"
  value       = azurerm_container_app_environment.env.name
}

output "default_domain" {
  description = "Default domain for apps in this environment"
  value       = azurerm_container_app_environment.env.default_domain
}

output "static_ip_address" {
  description = "Static IP address of the internal load balancer"
  value       = azurerm_container_app_environment.env.static_ip_address
}

output "dns_zone_id" {
  description = "Private DNS zone ID"
  value       = azurerm_private_dns_zone.cae_dns.id
}

output "wildcard_record_id" {
  description = "Wildcard A record ID (used for dependency management)"
  value       = azurerm_private_dns_a_record.cae_wildcard.id
}

output "private_endpoint_id" {
  description = "Private endpoint ID (if created in module - typically null when created in root)"
  value       = var.create_private_endpoint ? azurerm_private_endpoint.cae_pe[0].id : null
}
