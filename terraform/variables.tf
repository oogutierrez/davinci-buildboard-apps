# ---------------------------------------------------------------------------
# Subscription and Workspace Variables
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure Subscription ID to deploy resources into"
  type        = string
}

variable "davinci_pro_subscription_id" {
  description = "Azure Subscription ID for DAVINCI-PRO (where shared Private DNS zones are hosted)"
  type        = string
  default     = "31be81f5-fcff-4ec4-b88e-de233997e15e"
}

# ---------------------------------------------------------------------------
# Application Variables
# ---------------------------------------------------------------------------

variable "applicationname" {
  description = "Application name to be used in resource naming (lowercase alphanumeric only, max 10 chars)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.applicationname))
    error_message = "Application name must be lowercase alphanumeric only and max 10 characters."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "South Central US"
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

# ---------------------------------------------------------------------------
# Tagging Variables
# ---------------------------------------------------------------------------

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

variable "category" {
  description = "Category tag"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Network Variables
# ---------------------------------------------------------------------------

variable "existing_vnet_name" {
  description = "Name of the existing virtual network"
  type        = string

  validation {
    condition     = length(var.existing_vnet_name) > 0
    error_message = "VNet name cannot be empty."
  }
}

variable "existing_vnet_resource_group" {
  description = "Resource group of the existing virtual network"
  type        = string

  validation {
    condition     = length(var.existing_vnet_resource_group) > 0
    error_message = "VNet resource group name cannot be empty."
  }
}

variable "existing_app_subnet_name" {
  description = "Name of the existing subnet for Container App Environment infrastructure (must be delegated to Microsoft.App/environments and be at least /27)"
  type        = string

  validation {
    condition     = length(var.existing_app_subnet_name) > 0
    error_message = "App subnet name cannot be empty."
  }
}

variable "existing_pe_subnet_name" {
  description = "Name of the existing subnet for private endpoints"
  type        = string

  validation {
    condition     = length(var.existing_pe_subnet_name) > 0
    error_message = "Private endpoint subnet name cannot be empty."
  }
}

variable "existing_postgres_subnet_name" {
  description = "Name of the existing subnet for PostgreSQL (must be delegated to Microsoft.DBforPostgreSQL/flexibleServers)"
  type        = string

  validation {
    condition     = length(var.existing_postgres_subnet_name) > 0
    error_message = "PostgreSQL subnet name cannot be empty."
  }
}

variable "webapp_private_dns_zone_resource_group" {
  description = "Resource group of the existing private DNS zones (ACR, PostgreSQL)"
  type        = string
  default     = "dvpro-private-dns-zones-rg"
}

# ---------------------------------------------------------------------------
# Database Variables
# ---------------------------------------------------------------------------

variable "db_admin_username" {
  description = "PostgreSQL admin username (alphanumeric and underscores only, 1-63 chars)"
  type        = string
  default     = "n8nadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_admin_username))
    error_message = "Database username must start with a letter, contain only alphanumeric characters and underscores, and be 1-63 characters long."
  }
}

variable "db_admin_password" {
  description = "PostgreSQL admin password (if not provided, a random one will be generated)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "prevent_postgres_destroy" {
  description = "Whether to prevent destruction of the PostgreSQL server (to protect data). Set to true in non-dev environments."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# N8N Application Variables
# ---------------------------------------------------------------------------

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

variable "runners_auth_token" {
  description = "Authentication token for n8n runners (if not provided, a random one will be generated)"
  type        = string
  sensitive   = true
  default     = ""
}

# ---------------------------------------------------------------------------
# Web UI Variables
# ---------------------------------------------------------------------------

variable "webui_image" {
  description = "Full source image reference for the custom n8n web UI to import into ACR (e.g. docker.io/yourorg/n8n-webui:1.0). Leave empty if you push the image to ACR directly via CI."
  type        = string
  default     = ""
}

variable "webui_image_tag" {
  description = "Tag for the custom web UI image stored in ACR"
  type        = string
  default     = "latest"
}

variable "webui_port" {
  description = "Port that the custom web UI container listens on (1-65535)"
  type        = number
  default     = 3000

  validation {
    condition     = var.webui_port >= 1 && var.webui_port <= 65535
    error_message = "Port must be between 1 and 65535."
  }
}

variable "webui_dockerfile_path" {
  description = "Path to Dockerfile for building custom web UI image (alternative to webui_image). Leave empty to skip building."
  type        = string
  default     = ""
}

variable "webui_build_context" {
  description = "Build context directory for web UI Docker build (defaults to Dockerfile directory if not specified)"
  type        = string
  default     = ""
}
