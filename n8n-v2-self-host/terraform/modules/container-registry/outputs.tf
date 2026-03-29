output "id" {
  description = "Container registry ID"
  value       = azurerm_container_registry.acr.id
}

output "name" {
  description = "Container registry name"
  value       = azurerm_container_registry.acr.name
}

output "login_server" {
  description = "Container registry login server"
  value       = azurerm_container_registry.acr.login_server
}

output "n8n_image_import_complete" {
  description = "Trigger to indicate n8n images have been imported"
  value       = null_resource.import_n8n_images.id
}

output "webui_image_import_complete" {
  description = "Trigger to indicate webui image has been imported (if applicable)"
  value       = var.webui_source_image != "" ? null_resource.import_webui_image[0].id : null
}

output "webui_image_build_complete" {
  description = "Trigger to indicate webui image has been built (if applicable)"
  value       = var.webui_dockerfile_path != "" ? null_resource.build_webui_image[0].id : null
}

output "webui_image_ref" {
  description = "Full image reference for webui in ACR"
  value       = "${azurerm_container_registry.acr.login_server}/n8n-webui:${var.webui_image_tag}"
}
