terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "13d52521-10b9-4b99-91b7-a244d1a5a16b"
}


# Workspace validation - prevents using 'default' workspace for all operations (plan/apply/destroy). Throw an error if 'default' workspace is used.
resource "terraform_data" "workspace_validation" {
  lifecycle {
    precondition {
      condition     = terraform.workspace != "default"
      error_message = "ERROR: You must use a named workspace. Current workspace: ${terraform.workspace}. Use 'terraform workspace new <name>' to create one."
    }
  }

  input = terraform.workspace
}

# Variables
variable "applicationname" {
  description = "Application name to be used in resource naming"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = ""

  validation {
    condition     = contains(["development", "production", "staging", "qa"], lower(var.environment))
    error_message = "Invalid environment: ${var.environment}. Allowed values are development, production, staging, qa."
  }
}

locals {
  env_suffix = {
    development = "dev"
    production  = "pro"
    staging     = "stg"
    qa          = "qa"
  }
  env_key = lower(var.environment)
}

variable "costmanagement" {
  description = "CostManagement tag"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = ""
}

locals {
  required_tags = {
    CostManagement = var.costmanagement
    Owner          = var.owner
    Environment    = var.environment
  }
}

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
  default     = ""
}

variable "acr_resource_group" {
  description = "Resource group of the Azure Container Registry"
  type        = string
  default     = ""
}

variable "n8n_image_tag" {
  description = "n8n image tag"
  type        = string
  default     = "latest"
}

variable "n8n_encryption_key" {
  description = "n8n encryption key"
  type        = string
  default     = ""

  validation {
    condition     = length(var.n8n_encryption_key) >= 32
    error_message = "n8n_encryption_key must be at least 32 characters long."
  }
}

variable "db_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "n8nadmin"
}

variable "db_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
  default     = "TempPassword123!" # Will be used only during destroy
}

variable "user_assigned_identity_name" {
  description = "Name of the user-assigned managed identity"
  type        = string
  default     = "cpat-assistant-mi"
}

variable "user_assigned_identity_resource_group" {
  description = "Resource group of the user-assigned managed identity"
  type        = string
  default     = "oog-test-rg"
}

# Data sources
data "azurerm_container_registry" "acr" {
  count               = var.acr_name != "" ? 1 : 0
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

data "azurerm_user_assigned_identity" "app_identity" {
  name                = var.user_assigned_identity_name
  resource_group_name = var.user_assigned_identity_resource_group
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  location = var.location
  tags     = local.required_tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "privatevnet-${var.applicationname}-n8n"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
  tags                = merge(local.required_tags, { Description = "Internal and private virtual network. You may add private endpoints in the subnet-pe-* in this vnet. Do not peer to other vnet." })
}

# Subnet for App Service Integration
resource "azurerm_subnet" "app_subnet" {
  name                 = "subnet-app-${var.applicationname}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "pe_subnet" {
  name                 = "subnet-pe-${var.applicationname}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Subnet for PostgreSQL (requires delegation)
resource "azurerm_subnet" "postgres_subnet" {
  name                 = "subnet-postgres-${var.applicationname}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres_dns" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = merge(local.required_tags, { Description = "For resolution of the internal PostgreSQL server." })
}

# Link Private DNS Zone for PostgreSQL to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres_dns_link" {
  name                  = "postgres-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# PostgreSQL Flexible Server with Private Networking
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                         = "psql-${var.applicationname}-n8n"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "16"
  administrator_login          = var.db_admin_username
  administrator_password       = var.db_admin_password
  storage_mb                   = 32768             # 32 GB - minimum
  sku_name                     = "B_Standard_B1ms" # Cheapest burstable tier
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # Disable public network access (required by policy)
  public_network_access_enabled = false

  # Enable private networking
  delegated_subnet_id = azurerm_subnet.postgres_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres_dns.id

  zone = "1"

  tags                = merge(local.required_tags, { Description = "Internal and private PostgreSQL server to persist settings and workflow data." })

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres_dns_link
  ]
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "n8n_db" {
  name      = "n8n"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# App Service Plan (Linux, Basic B1 - cheapest viable option)
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.applicationname}-n8n"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1" # Basic tier - cheapest for containers
  tags                = merge(local.required_tags, { Description = "Adjustable service plan for n8n application." })
}

# App Service (Web App)
resource "azurerm_linux_web_app" "webapp" {
  name                = "${var.applicationname}-n8n"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id

  virtual_network_subnet_id = azurerm_subnet.app_subnet.id

  site_config {
    always_on = false

    application_stack {
      docker_image_name        = "n8n:latest"
      docker_registry_url      = var.acr_name != "" ? "https://${data.azurerm_container_registry.acr[0].login_server}" : null
      docker_registry_username = null
      docker_registry_password = null
    }
    container_registry_use_managed_identity       = var.acr_name != "" ? true : false
    container_registry_managed_identity_client_id = var.acr_name != "" ? data.azurerm_user_assigned_identity.app_identity.client_id : null
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = "false"
    "DOCKER_ENABLE_CI"                      = "true"
    "DB_TYPE"                               = "postgresdb"
    "DB_POSTGRESDB_HOST"                    = azurerm_postgresql_flexible_server.postgres.fqdn
    "DB_POSTGRESDB_PORT"                    = "5432"
    "DB_POSTGRESDB_DATABASE"                = azurerm_postgresql_flexible_server_database.n8n_db.name
    "DB_POSTGRESDB_USER"                    = var.db_admin_username
    "DB_POSTGRESDB_PASSWORD"                = var.db_admin_password
    "N8N_HOST"                              = "${var.applicationname}-n8n.azurewebsites.net"
    "N8N_PROTOCOL"                          = "https"
    "NODE_ENV"                              = var.environment != "" ? var.environment : ""
    "N8N_ENCRYPTION_KEY"                    = var.n8n_encryption_key
    "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS" = "true"
    "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED" = "false"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.app_identity.id]
  }

  https_only = true

  public_network_access_enabled = false

  tags                = merge(local.required_tags, { Description = "The n8n web application." })
}

# VNet Integration for Web App
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_linux_web_app.webapp.id
  subnet_id      = azurerm_subnet.app_subnet.id
}

# Private DNS Zone for Web App
resource "azurerm_private_dns_zone" "webapp_dns" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = merge(local.required_tags, { Description = "For internal resolution of the n8n web application." })
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "webapp_dns_link" {
  name                  = "webapp-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.webapp_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# Private Endpoint for Web App
resource "azurerm_private_endpoint" "webapp_pe" {
  name                = "pe-${var.applicationname}-webapp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                           = "psc-${var.applicationname}-webapp"
    private_connection_resource_id = azurerm_linux_web_app.webapp.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "webapp-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.webapp_dns.id]
  }
  tags                = merge(local.required_tags, { Description = "Internal private endpoint only for the n8n web app. Do not use this endpoint to connect to it. Create another one for external access." })
}

# Outputs
output "webapp_url" {
  value       = "https://${azurerm_linux_web_app.webapp.default_hostname}"
  description = "Web App public URL"
}

output "webapp_name" {
  value       = azurerm_linux_web_app.webapp.name
  description = "Web App name"
}

output "postgres_fqdn" {
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
  description = "PostgreSQL server FQDN"
}

output "private_endpoint_ip" {
  value       = azurerm_private_endpoint.webapp_pe.private_service_connection[0].private_ip_address
  description = "Private endpoint IP address"
}

output "vnet_name" {
  value       = azurerm_virtual_network.vnet.name
  description = "Virtual Network name"
}

output "user_assigned_identity_id" {
  value       = data.azurerm_user_assigned_identity.app_identity.id
  description = "User-assigned managed identity ID"
}

output "user_assigned_identity_principal_id" {
  value       = data.azurerm_user_assigned_identity.app_identity.principal_id
  description = "User-assigned managed identity principal ID"
}
