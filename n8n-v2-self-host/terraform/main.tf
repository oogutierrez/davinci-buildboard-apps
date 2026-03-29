# ---------------------------------------------------------------------------
# Workspace Validation
# ---------------------------------------------------------------------------

resource "terraform_data" "workspace_validation" {
  lifecycle {
    precondition {
      condition     = terraform.workspace != "default"
      error_message = "ERROR: You must use a named workspace. Current workspace: ${terraform.workspace}. Use 'terraform workspace new <name>' to create one."
    }
  }
  input = terraform.workspace
}

# ---------------------------------------------------------------------------
# Local Variables
# ---------------------------------------------------------------------------

locals {
  env_suffix = {
    development = "dev"
    production  = "pro"
    staging     = "stg"
    qa          = "qa"
  }
  env_key = lower(var.environment)

  required_tags = {
    CostManagement = var.costmanagement
    Owner          = var.owner
    Category       = var.category
  }
}

# ---------------------------------------------------------------------------
# Random Resources for Secure Secrets
# ---------------------------------------------------------------------------

resource "random_password" "db_admin_password" {
  count   = var.db_admin_password == "" ? 1 : 0
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "random_password" "runners_auth_token" {
  count   = var.runners_auth_token == "" ? 1 : 0
  length  = 64
  special = false
  upper   = true
  lower   = true
  numeric = true
}

locals {
  db_password        = var.db_admin_password != "" ? var.db_admin_password : random_password.db_admin_password[0].result
  runners_auth_token = var.runners_auth_token != "" ? var.runners_auth_token : random_password.runners_auth_token[0].result
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "existing_vnet" {
  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_resource_group
}

data "azurerm_subnet" "existing_app_subnet" {
  name                 = var.existing_app_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group
}

data "azurerm_subnet" "existing_pe_subnet" {
  name                 = var.existing_pe_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group
}

data "azurerm_subnet" "existing_postgres_subnet" {
  name                 = var.existing_postgres_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group
}

data "azurerm_private_dns_zone" "acr_dns" {
  name                = "privatelink.azurecr.io"
  provider            = azurerm.subscription_davinci_pro
  resource_group_name = var.webapp_private_dns_zone_resource_group
}

data "azurerm_private_dns_zone" "postgres_dns" {
  name                = "privatelink.postgres.database.azure.com"
  provider            = azurerm.subscription_davinci_pro
  resource_group_name = var.webapp_private_dns_zone_resource_group
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  location = var.location
  tags     = local.required_tags
}

# ---------------------------------------------------------------------------
# Managed Identity Module
# ---------------------------------------------------------------------------

module "managed_identity" {
  source = "./modules/managed-identity"

  identity_name       = "mi-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = merge(local.required_tags, { Description = "Managed identity for n8n application to access ACR and PostgreSQL." })
}

# ---------------------------------------------------------------------------
# Container Registry Module
# ---------------------------------------------------------------------------

module "container_registry" {
  source = "./modules/container-registry"

  registry_name                  = "cr${var.applicationname}n8n${local.env_suffix[local.env_key]}"
  resource_group_name            = azurerm_resource_group.rg.name
  location                       = azurerm_resource_group.rg.location
  subscription_id                = var.subscription_id
  sku                            = "Premium"
  private_endpoint_name          = "pe-cr-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  private_endpoint_subnet_id     = data.azurerm_subnet.existing_pe_subnet.id
  acr_private_dns_zone_id        = data.azurerm_private_dns_zone.acr_dns.id
  managed_identity_principal_id  = module.managed_identity.principal_id
  n8n_image_tag                  = var.n8n_image_tag
  webui_source_image             = var.webui_image
  webui_image_tag                = var.webui_image_tag
  webui_dockerfile_path          = var.webui_dockerfile_path
  webui_build_context            = var.webui_build_context
  tags                           = merge(local.required_tags, { Description = "Container registry for n8n application images." })
}

# ---------------------------------------------------------------------------
# PostgreSQL Module
# ---------------------------------------------------------------------------

module "postgresql" {
  source = "./modules/postgresql"

  server_name                   = "psql-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  postgres_version              = "16"
  admin_username                = var.db_admin_username
  admin_password                = local.db_password
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms"
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  delegated_subnet_id           = data.azurerm_subnet.existing_postgres_subnet.id
  private_dns_zone_id           = data.azurerm_private_dns_zone.postgres_dns.id
  zone                          = "1"
  database_name                 = "n8n"
  database_charset              = "UTF8"
  database_collation            = "en_US.utf8"
  managed_identity_principal_id = module.managed_identity.principal_id
  #prevent_destroy               = var.prevent_postgres_destroy
  tags                          = merge(local.required_tags, { Description = "Internal and private PostgreSQL server to persist settings and workflow data." })
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = merge(local.required_tags, { Description = "Log Analytics workspace for Container App Environment monitoring." })
}

# ---------------------------------------------------------------------------
# Container App Environment Module
# ---------------------------------------------------------------------------

module "container_app_environment" {
  source = "./modules/container-app-environment"

  environment_name               = "cae-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  resource_group_name            = azurerm_resource_group.rg.name
  location                       = azurerm_resource_group.rg.location
  infrastructure_subnet_id       = data.azurerm_subnet.existing_app_subnet.id
  internal_load_balancer_enabled = true
  virtual_network_id             = data.azurerm_virtual_network.existing_vnet.id
  create_private_endpoint        = true  # Private endpoint created separately at the end
  private_endpoint_name          = "pe-cae-${var.applicationname}-n8n-${local.env_suffix[local.env_key]}"
  private_endpoint_subnet_id     = data.azurerm_subnet.existing_pe_subnet.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  tags                           = merge(local.required_tags, { Description = "Container App Environment for n8n (internal, VNet-integrated)." })
}

# ---------------------------------------------------------------------------
# N8N Main Container App Module
# ---------------------------------------------------------------------------

module "n8n_main" {
  source = "./modules/container-app"

  app_name                     = "${var.applicationname}-n8n-main-${local.env_suffix[local.env_key]}"
  container_app_environment_id = module.container_app_environment.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  min_replicas                 = 1
  max_replicas                 = 1
  container_name               = "n8n-main"
  container_image              = "${module.container_registry.login_server}/n8n:${var.n8n_image_tag}"
  cpu                          = 1.0
  memory                       = "2Gi"

  environment_variables = [
    { name = "DB_TYPE", value = "postgresdb" },
    { name = "DB_POSTGRESDB_HOST", value = module.postgresql.server_fqdn },
    { name = "DB_POSTGRESDB_PORT", value = "5432" },
    { name = "DB_POSTGRESDB_DATABASE", value = module.postgresql.database_name },
    { name = "DB_POSTGRESDB_USER", value = var.db_admin_username },
    { name = "DB_POSTGRESDB_PASSWORD", secret_name = "db-admin-password" },
    { name = "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED", value = "false" },
    { name = "N8N_HOST", value = "${var.applicationname}-n8n-${local.env_suffix[local.env_key]}.${module.container_app_environment.default_domain}" },
    { name = "N8N_PROTOCOL", value = "https" },
    { name = "WEBHOOK_URL", value = "https://${var.applicationname}-n8n-${local.env_suffix[local.env_key]}.${module.container_app_environment.default_domain}/" },
    { name = "NODE_ENV", value = var.environment },
    { name = "N8N_ENCRYPTION_KEY", secret_name = "n8n-encryption-key" },
    { name = "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS", value = "true" },
    #{ name = "N8N_RUNNERS_ENABLED", value = "true" }, deprecated
    { name = "N8N_RUNNERS_MODE", value = "external" },
    { name = "N8N_RUNNERS_AUTH_TOKEN", secret_name = "runners-auth-token" },
    { name = "N8N_RUNNERS_BROKER_LISTEN_ADDRESS", value = "0.0.0.0" },
    { name = "EXECUTIONS_MODE", value = "regular" },
    { name = "N8N_NATIVE_PYTHON_RUNNER", value = "true" },
    { name = "N8N_PUBLIC_API_DISABLED", value = "false" }
  ]

  ingress = {
    external_enabled = true
    target_port      = 5678
    transport        = "http"
  }

  registry_server      = module.container_registry.login_server
  registry_identity_id = module.managed_identity.id
  identity_id          = module.managed_identity.id

  secrets = [
    { name = "db-admin-password", value = local.db_password },
    { name = "n8n-encryption-key", value = var.n8n_encryption_key },
    { name = "runners-auth-token", value = local.runners_auth_token },
  ]

  tags = merge(local.required_tags, { Description = "The n8n web application." })

  depends_on = [
    module.container_registry,
    module.container_app_environment,
    module.postgresql
  ]
}

# ---------------------------------------------------------------------------
# N8N Runner Container App Module
# ---------------------------------------------------------------------------

module "n8n_runner" {
  source = "./modules/container-app"

  app_name                     = "${var.applicationname}-n8n-runner-${local.env_suffix[local.env_key]}"
  container_app_environment_id = module.container_app_environment.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  min_replicas                 = 1
  max_replicas                 = 3
  container_name               = "n8n-runner"
  container_image              = "${module.container_registry.login_server}/runners:${var.n8n_image_tag}"
  cpu                          = 0.5
  memory                       = "1Gi"

  environment_variables = [
    {
      name  = "N8N_RUNNERS_TASK_BROKER_URI"
      value = "http://${module.n8n_main.name}:5679"
    },
    {
      name        = "N8N_RUNNERS_AUTH_TOKEN"
      secret_name = "runners-auth-token"
    }
  ]

  # No ingress - runner only connects outbound to n8n main
  ingress = null

  registry_server      = module.container_registry.login_server
  registry_identity_id = module.managed_identity.id
  identity_id          = module.managed_identity.id

  secrets = [
    { name = "runners-auth-token", value = local.runners_auth_token }
  ]

  tags = merge(local.required_tags, { Description = "The n8n runner application." })

  depends_on = [
    module.container_registry,
    module.container_app_environment,
    module.postgresql
  ]
}

# ---------------------------------------------------------------------------
# N8N Web UI Container App Module
# IMPORTANT: Depends on both n8n_main and n8n_runner to ensure they are
# fully deployed before the web UI starts
# ---------------------------------------------------------------------------

module "n8n_webui" {
  source = "./modules/container-app"

  app_name                     = "${var.applicationname}-n8n-webui-${local.env_suffix[local.env_key]}"
  container_app_environment_id = module.container_app_environment.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  min_replicas                 = 1
  max_replicas                 = 2
  container_name               = "webui"
  container_image              = module.container_registry.webui_image_ref
  cpu                          = 0.5
  memory                       = "1Gi"

  environment_variables = [
    {
      name  = "NODE_ENV"
      value = "production" #var.environment
    },
    {
      name = "PORT"
      value = tostring(var.webui_port)
    },
    {
      name  = "N8N_API_URL"
      value = "http://${module.n8n_main.name}.internal.${module.container_app_environment.default_domain}"
    },
    {
      name = "N8N_API_KEY"
      secret_name = "n8n-api-key"
    },
    {
      name = "JWT_SECRET"
      secret_name = "jwt-secret"
    },
    {
      name  = "ADMIN_USERNAME"
      value = "admin"
    },
    {
      name        = "ADMIN_PASSWORD"
      secret_name = "admin-password"
    }
  ]

  liveness_probe = {
    transport               = "HTTP"
    path                    = "/health"
    port                    = var.webui_port
    initial_delay           = 10
    period_seconds          = 30
    failure_count_threshold = 3
  }

  readiness_probe = {
    transport               = "HTTP"
    path                    = "/health"
    port                    = var.webui_port
    period_seconds          = 10
    failure_count_threshold = 3
  }

  ingress = {
    external_enabled = true
    target_port      = var.webui_port
    transport        = "http"
  }

  registry_server      = module.container_registry.login_server
  registry_identity_id = module.managed_identity.id
  identity_id          = module.managed_identity.id

  secrets = [
    # These are for the sample web UI to call the API - we create secrets for them here and then reference them in the web UI module to ensure they are all created before the web UI tries to deploy
    { name = "jwt-secret", value = "your_jwt_secret_here_change_in_production" },
    { name = "n8n-api-key", value = "your_n8n_api_key_here_change_in_production" },
    { name = "admin-password", value = "admin123" },
  ]

  tags = merge(local.required_tags, { Description = "Custom web UI front-end for the n8n application." })

  # CRITICAL: This ensures webui deploys AFTER both main and runner are complete
  depends_on = [
    module.n8n_main,
    module.n8n_runner,
    module.container_registry
  ]
}


