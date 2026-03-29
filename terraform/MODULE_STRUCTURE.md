# Modular Terraform Structure for N8N Container Apps

This document describes the modular architecture of the N8N Container Apps deployment.

## Overview

The configuration has been refactored from a monolithic single-file structure into a modular architecture following Terraform best practices. This improves maintainability, reusability, and testability.

## Directory Structure

```
n8n-v2-container-apps/
├── modules/
│   ├── managed-identity/          # User-assigned identity module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── container-registry/        # ACR with private endpoints and image imports
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── postgresql/                # PostgreSQL Flexible Server with database
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── container-app-environment/ # Container App Environment with DNS
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── container-app/             # Reusable container app module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── main.tf                        # Root module orchestration
├── variables.tf                   # Root module variables
├── outputs.tf                     # Root module outputs
├── versions.tf                    # Terraform and provider versions
├── backend.tf                     # Backend configuration (state storage)
├── backend.tfvars.example         # Backend configuration example
├── app1-dev.tfvars               # Environment-specific variables
└── MODULE_STRUCTURE.md            # This file
```

## Module Descriptions

### 1. managed-identity

**Purpose**: Creates and manages Azure User-Assigned Managed Identity

**Resources**:
- `azurerm_user_assigned_identity`

**Outputs**:
- `id` - Identity resource ID
- `principal_id` - Service principal ID (sensitive)
- `client_id` - Application client ID (sensitive)
- `name` - Identity name

**Usage**: Used to grant container apps access to ACR and PostgreSQL

---

### 2. container-registry

**Purpose**: Creates ACR with private endpoint and imports container images

**Resources**:
- `azurerm_container_registry` - Premium SKU ACR
- `azurerm_private_endpoint` - Private endpoint for ACR
- `azurerm_role_assignment` - AcrPull role for managed identity
- `null_resource.import_n8n_images` - Imports n8n and runners images
- `null_resource.import_webui_image` - Conditionally imports webui image

**Key Features**:
- Automatic image import from Docker Hub
- Private endpoint for secure access
- Role-based access control

**Outputs**:
- `login_server` - ACR login server URL
- `name` - ACR name
- `n8n_image_import_complete` - Dependency trigger
- `webui_image_ref` - Full webui image reference

---

### 3. postgresql

**Purpose**: Creates PostgreSQL Flexible Server with database

**Resources**:
- `azurerm_postgresql_flexible_server` - PostgreSQL 16 server
- `azurerm_postgresql_flexible_server_database` - n8n database
- `azurerm_role_assignment` - Reader role for managed identity

**Key Features**:
- VNet integration via delegated subnet
- Private DNS zone integration
- Lifecycle protection (prevent_destroy)
- Password change protection (ignore_changes)

**Outputs**:
- `server_fqdn` - PostgreSQL server FQDN
- `database_name` - Database name

---

### 4. container-app-environment

**Purpose**: Creates Container App Environment with DNS configuration

**Resources**:
- `azurerm_container_app_environment` - Internal CAE
- `azurerm_private_dns_zone` - Environment-specific DNS zone
- `azurerm_private_dns_zone_virtual_network_link` - VNet DNS link
- `azurerm_private_dns_a_record` - Wildcard A record
- `azurerm_private_endpoint` - Optional private endpoint

**Key Features**:
- Internal load balancer
- Automatic DNS zone creation
- Wildcard DNS for all apps
- VNet integration

**Outputs**:
- `id` - Environment ID
- `default_domain` - Environment domain
- `static_ip_address` - Internal LB IP
- `wildcard_record_id` - For dependency management

---

### 5. container-app

**Purpose**: Reusable module for deploying container apps

**Resources**:
- `azurerm_container_app` - Container app with configurable settings

**Key Features**:
- Flexible environment variable configuration
- Optional ingress configuration
- Optional health probes (liveness/readiness)
- Secret management
- Scaling configuration
- Managed identity integration

**Usage**: Used three times in root module:
1. **n8n-main** - Main n8n application
2. **n8n-runner** - Worker processes for n8n
3. **n8n-webui** - Custom web UI front-end

**Outputs**:
- `id` - Container app ID
- `name` - Container app name
- `latest_revision_fqdn` - App FQDN

---

## Root Module (main.tf)

The root module orchestrates all child modules and manages:

1. **Resource Group Creation**
2. **Data Sources** - Existing VNet, subnets, DNS zones
3. **Random Password Generation** - For DB and runners token
4. **Module Instantiation** - Calls all child modules
5. **Dependency Management** - Ensures correct deployment order

### Deployment Order

The deployment follows this sequence:

```
1. managed_identity
2. container_registry (depends on identity)
3. postgresql (depends on identity)
4. container_app_environment (WITHOUT private endpoint)
5. n8n_main (depends on registry, environment, wildcard DNS)
6. n8n_runner (depends on registry, environment)
7. n8n_webui (depends on n8n_main, n8n_runner, registry) ⬅️ CRITICAL
8. cae_private_endpoint (depends on ALL apps) ⬅️ CREATED LAST!
```

### Deployment Dependency Chain

#### Web UI Dependency

The n8n-webui module has explicit dependencies to ensure it deploys **AFTER** both n8n-main and n8n-runner:

```terraform
module "n8n_webui" {
  # ... configuration ...

  depends_on = [
    module.n8n_main,      # Wait for main app
    module.n8n_runner,    # Wait for runner
    module.container_registry
  ]
}
```

**Why this matters**:
- The web UI proxies requests to n8n-main
- It may need both main and runner to be fully operational
- Prevents race conditions during initial deployment

#### Private Endpoint Created Last (CRITICAL)

The Container App Environment private endpoint is created **AFTER** all container apps:

```terraform
resource "azurerm_private_endpoint" "cae_pe" {
  # ... configuration ...

  depends_on = [
    module.n8n_main,
    module.n8n_runner,
    module.n8n_webui  # Wait for ALL apps!
  ]
}
```

**Why this matters**:
- Ensures all apps are fully deployed and operational
- Private endpoint exposes the entire environment
- Prevents exposing incomplete/broken deployment
- Cleaner rollout with no downtime risk

## Benefits of Modular Structure

### 1. **Reusability**
- The `container-app` module is used three times
- Modules can be reused across different projects
- Consistent configuration patterns

### 2. **Maintainability**
- Each module has a single responsibility
- Easier to understand and modify
- Changes isolated to specific modules

### 3. **Testability**
- Modules can be tested independently
- Easier to write unit tests
- Faster feedback loops

### 4. **Scalability**
- Easy to add new container apps
- Can version modules independently
- Supports multi-environment deployments

### 5. **Dependency Management**
- Clear dependency chains
- Explicit `depends_on` where needed
- Prevents deployment race conditions

### 6. **Security**
- Sensitive outputs properly marked
- Secrets managed consistently
- RBAC configured per module

## Usage Examples

### Deploy Everything

```bash
# Initialize with backend config
terraform init -backend-config="backend.tfvars"

# Create/select workspace
terraform workspace new app1-dev

# Plan with variables
terraform plan -var-file="app1-dev.tfvars"

# Apply
terraform apply -var-file="app1-dev.tfvars"
```

### Deploy Individual Modules (Advanced)

```bash
# Deploy only the container registry
terraform apply -target=module.container_registry -var-file="app1-dev.tfvars"

# Deploy web UI after main and runner are confirmed working
terraform apply -target=module.n8n_webui -var-file="app1-dev.tfvars"
```

### Update Container App

```bash
# Change only the n8n-main app
terraform apply -target=module.n8n_main -var-file="app1-dev.tfvars"
```

## Migration from Monolithic Structure

If migrating from the previous `main-containerapps-customui.tf`:

1. **Backup State**:
   ```bash
   terraform state pull > backup.tfstate
   ```

2. **Initialize New Structure**:
   ```bash
   terraform init -backend-config="backend.tfvars"
   ```

3. **Import Existing Resources** (if needed):
   ```bash
   # Example for resource group
   terraform import azurerm_resource_group.rg /subscriptions/.../resourceGroups/rg-name
   ```

4. **Plan and Verify**:
   ```bash
   terraform plan -var-file="app1-dev.tfvars"
   ```

   Should show minimal changes (mostly metadata)

5. **Apply**:
   ```bash
   terraform apply -var-file="app1-dev.tfvars"
   ```

## Variables Configuration

All variables are defined in `variables.tf` and can be provided via:

1. **tfvars file** (recommended):
   ```bash
   terraform apply -var-file="app1-dev.tfvars"
   ```

2. **Environment variables**:
   ```bash
   export TF_VAR_applicationname="app1"
   terraform apply
   ```

3. **Command line**:
   ```bash
   terraform apply -var="applicationname=app1"
   ```

## Outputs

After deployment, retrieve outputs:

```bash
# All outputs
terraform output

# Specific output
terraform output n8n_url

# Sensitive outputs
terraform output -json db_admin_password
```

## Best Practices

1. **Always Use Workspaces**
   - Separate state for each environment
   - Prevents accidental cross-environment changes

2. **Use tfvars Files**
   - One file per environment
   - Version control friendly
   - Easy to review

3. **Pin Module Versions**
   - Use git tags or version numbers
   - Ensures reproducible deployments

4. **Document Changes**
   - Update module README files
   - Document breaking changes
   - Use semantic versioning

5. **Test Modules Independently**
   - Use Terratest or similar
   - Validate before root module integration

## Troubleshooting

### Module Not Found

```bash
terraform init
```

Reinitialize to load module sources.

### Dependency Issues

If deployment order is wrong, add explicit `depends_on`:

```terraform
module "my_app" {
  # ... config ...
  depends_on = [module.dependency]
}
```

### State Lock Issues

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Module Output Access

Outputs from child modules are accessed with `module.<name>.<output>`:

```terraform
value = module.container_registry.login_server
```

## Future Enhancements

Potential improvements to the modular structure:

1. **Module Registry** - Publish modules to private registry
2. **Automated Testing** - CI/CD pipeline for module testing
3. **Multi-Region** - Support for multi-region deployments
4. **Monitoring Module** - Add Azure Monitor configuration
5. **Backup Module** - Automated backup configuration
6. **Security Module** - Azure Security Center integration

## Support

For issues or questions:
- Review module-specific README files
- Check Terraform plan output carefully
- Verify variable values in tfvars
- Ensure prerequisites exist (VNet, subnets, DNS zones)
