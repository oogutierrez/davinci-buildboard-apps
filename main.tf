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
  subscription_id = "13d52521-10b9-4b99-91b7-a244d1a5a16b" #DAVINCI-DEV
}

provider "azurerm" {
  alias           = "subscription_davincipro"
  features {}
  subscription_id = "31be81f5-fcff-4ec4-b88e-de233997e15e" #DAVINCI-PRO
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

variable "webapp_pe_subnet_name" {
  description = "Name of the existing subnet for webapp private endpoint"
  type        = string
  default     = "PRIVATE_SUBNET_01"
}

variable "webapp_pe_subnet_vnet_name" {
  description = "Name of the VNet containing the webapp PE subnet"
  type        = string
  default     = "davincidev-coreservices-vnet"
}

variable "webapp_pe_subnet_resource_group" {
  description = "Resource group of the VNet containing the webapp PE subnet"
  type        = string
  default     = "davincidev-coreservices-rg"
}

variable "webapp_private_dns_zone_name" {
  description = "Name of the existing private DNS zone for webapp"
  type        = string
  default     = "privatelink.azurewebsites.net"
}

variable "webapp_private_dns_zone_resource_group" {
  description = "Resource group of the existing private DNS zone for webapp"
  type        = string
  default     = "dvpro-private-dns-zones-rg"
}

# Data sources
data "azurerm_subnet" "webapp_pe_subnet" {
  name                 = var.webapp_pe_subnet_name
  virtual_network_name = var.webapp_pe_subnet_vnet_name
  resource_group_name  = var.webapp_pe_subnet_resource_group
}

data "azurerm_private_dns_zone" "webapp_dns" {
  provider            = azurerm.subscription_davincipro
  name                = var.webapp_private_dns_zone_name
  resource_group_name = var.webapp_private_dns_zone_resource_group
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  location = var.location
  tags     = local.required_tags
}

# User-Assigned Managed Identity
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "mi-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = merge(local.required_tags, { Description = "Managed identity for n8n application to access ACR and PostgreSQL." })
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "acr${var.applicationname}n8n${local.env_suffix[local.env_key]}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"
  admin_enabled       = false

  public_network_access_enabled = false

  tags = merge(local.required_tags, { Description = "Container registry for n8n application images." })
}

# Private DNS Zone for ACR
resource "azurerm_private_dns_zone" "acr_dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = merge(local.required_tags, { Description = "For internal resolution of the container registry." })
}

# Link Private DNS Zone for ACR to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  name                  = "acr-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# Private Endpoint for ACR
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-${var.applicationname}-acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                           = "psc-${var.applicationname}-acr"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr_dns.id]
  }

  tags = merge(local.required_tags, { Description = "Internal private endpoint for container registry access." })
}

# Role Assignment: Allow managed identity to pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# Import n8n image to ACR using null_resource
resource "null_resource" "import_n8n_image" {
  triggers = {
    acr_id     = azurerm_container_registry.acr.id
    image_tag  = var.n8n_image_tag
  }

  provisioner "local-exec" {
    command = "az acr import --name ${azurerm_container_registry.acr.name} --source docker.io/n8nio/n8n:${var.n8n_image_tag} --image n8n:${var.n8n_image_tag} --resource-group ${azurerm_resource_group.rg.name}"
  }

  depends_on = [
    azurerm_container_registry.acr,
    azurerm_private_endpoint.acr_pe
  ]
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

# Subnet for Private Endpoints (ACR and internal resources)
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

# Role Assignment: Grant managed identity Reader role on PostgreSQL
resource "azurerm_role_assignment" "postgres_reader" {
  scope                = azurerm_postgresql_flexible_server.postgres.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
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
      docker_image_name        = "n8n:${var.n8n_image_tag}"
      docker_registry_url      = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = null
      docker_registry_password = null
    }
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app_identity.client_id
    
    # Route container image pulls through VNet
    vnet_route_all_enabled = true
  }

  # VNet Integration Configuration
  vnet_image_pull_enabled = true

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
    "WEBHOOK_URL"                          = "https://${var.applicationname}-n8n.azurewebsites.net/"
    "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED" = "false"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_identity.id]
  }

  https_only = true

  public_network_access_enabled = false

  tags = merge(local.required_tags, { Description = "The n8n web application." })

  depends_on = [
    null_resource.import_n8n_image,
    azurerm_role_assignment.acr_pull
  ]
}

# Private Endpoint for Web App (using existing subnet and DNS)
resource "azurerm_private_endpoint" "webapp_pe" {
  name                = "pe-${var.applicationname}-webapp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "East US" #azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.webapp_pe_subnet.id

  private_service_connection {
    name                           = "psc-${var.applicationname}-webapp"
    private_connection_resource_id = azurerm_linux_web_app.webapp.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "webapp-dns-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.webapp_dns.id]
  }
  
  tags = merge(local.required_tags, { Description = "Private endpoint for external access to the n8n web app." })
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
  value       = azurerm_user_assigned_identity.app_identity.id
  description = "User-assigned managed identity ID"
}

output "user_assigned_identity_principal_id" {
  value       = azurerm_user_assigned_identity.app_identity.principal_id
  description = "User-assigned managed identity principal ID"
}

output "user_assigned_identity_client_id" {
  value       = azurerm_user_assigned_identity.app_identity.client_id
  description = "User-assigned managed identity client ID"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server URL"
}

output "acr_name" {
  value       = azurerm_container_registry.acr.name
  description = "ACR name"
}