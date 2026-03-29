resource "azurerm_container_registry" "acr" {
  name                          = var.registry_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = var.tags

  network_rule_bypass_option = "AzureServices"

  lifecycle {
    ignore_changes = [tags["LastModified"]]
  }
}

resource "azurerm_private_endpoint" "acr_pe" {
  name                = var.private_endpoint_name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.private_endpoint_name}-psc"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [var.acr_private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = var.managed_identity_principal_id
}

# Import n8n and runner images
resource "null_resource" "import_n8n_images" {
  triggers = {
    acr_id    = azurerm_container_registry.acr.id
    image_tag = var.n8n_image_tag
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    # Commenting this out for now since there is a pull request limit in docker hub that is being hit. Once we have the images in our ACR we can switch back to pulling from there instead of docker hub.
    # command     = <<-EOT
    #   az account set --subscription ${var.subscription_id} && \
    #   az acr import \
    #     --name ${azurerm_container_registry.acr.name} \
    #     --source docker.io/n8nio/n8n:${var.n8n_image_tag} \
    #     --image n8n:${var.n8n_image_tag} \
    #     --resource-group ${var.resource_group_name} \
    #     --force && \
    #   az acr import \
    #     --name ${azurerm_container_registry.acr.name} \
    #     --source docker.io/n8nio/runners:${var.n8n_image_tag} \
    #     --image runners:${var.n8n_image_tag} \
    #     --resource-group ${var.resource_group_name} \
    #     --force
    # EOT

    # Taking the images from an existing ACR in the same tenant to avoid docker hub pull limits. This ACR is not in the same subscription but since it's a cross-tenant pull it should work without any issues.
    command     = <<-EOT
      az account set --subscription ${var.subscription_id} && \
      az acr import \
        --name ${azurerm_container_registry.acr.name} \
        --source crdvpfdavinciutomationdev.azurecr.io/n8n:${var.n8n_image_tag} \
        --image n8n:${var.n8n_image_tag} \
        --resource-group ${var.resource_group_name} \
        --force && \
      az acr import \
        --name ${azurerm_container_registry.acr.name} \
        --source crdvpfdavinciutomationdev.azurecr.io/runners:${var.n8n_image_tag} \
        --image runners:${var.n8n_image_tag} \
        --resource-group ${var.resource_group_name} \
        --force
    EOT
  }

  depends_on = [
    azurerm_container_registry.acr,
    azurerm_private_endpoint.acr_pe
  ]
}

# Import web UI image from external registry (optional)
resource "null_resource" "import_webui_image" {
  count = var.webui_source_image != "" ? 1 : 0

  triggers = {
    acr_id      = azurerm_container_registry.acr.id
    webui_image = var.webui_source_image
    image_tag   = var.webui_image_tag
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "az account set --subscription ${var.subscription_id} && az acr import --name ${azurerm_container_registry.acr.name} --source ${var.webui_source_image} --image n8n-webui:${var.webui_image_tag} --resource-group ${var.resource_group_name} --force"
  }

  depends_on = [
    azurerm_container_registry.acr,
    azurerm_private_endpoint.acr_pe
  ]
}

# Build web UI image from Dockerfile (optional)
resource "null_resource" "build_webui_image" {
  count = var.webui_dockerfile_path != "" ? 1 : 0

  triggers = {
    acr_id         = azurerm_container_registry.acr.id
    dockerfile     = var.webui_dockerfile_path
    build_context  = var.webui_build_context
    image_tag      = var.webui_image_tag
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      PYTHONIOENCODING = "utf-8"
    }
    command = <<EOT
      az account set --subscription "${var.subscription_id}" && az acr build --registry "${azurerm_container_registry.acr.name}" --resource-group "${var.resource_group_name}" --image "n8n-webui:${var.webui_image_tag}" --file "${var.webui_dockerfile_path}" --no-logs "${var.webui_build_context != "" ? var.webui_build_context : dirname(var.webui_dockerfile_path)}"
    EOT
  }

  depends_on = [
    azurerm_container_registry.acr,
    azurerm_private_endpoint.acr_pe
  ]
}
