# N8N Azure Deployment with Terraform

This Terraform configuration deploys a **secure n8n workflow automation platform** on Azure with **private networking** and **managed identity authentication**.

---

## Architecture Overview

This deployment creates:

- **Azure App Service** running n8n in a Linux container  
- **PostgreSQL Flexible Server (v16)** for n8n data storage  
- **Private networking** with VNet integration and private endpoints  
- **User-assigned managed identity** for secure ACR authentication  
- **Private DNS zones** for internal name resolution  

> All resources are deployed with **private networking enabled**, ensuring secure communication between components.

---

## Prerequisites

- Terraform >= 1.0  
- Azure CLI installed and authenticated  
- Azure subscription with appropriate permissions  
- Existing user-assigned managed identity (for ACR access)  
- Optional: Azure Container Registry with n8n image  

---

## Resource Naming Convention

| Resource | Pattern |
|----------|---------|
| Resource Group | `rg-{applicationname}-n8n` |
| App Service | `{applicationname}-n8n` |
| PostgreSQL Server | `psql-{applicationname}-n8n` |
| Virtual Network | `privatevnet-{applicationname}-n8n` |

---

## Quick Start

### 1. Create a Terraform Workspace

> **Important:** This configuration requires a **named workspace** following the pattern: `{applicationname}-{environment}`
> 
> - **applicationname**: Your application identifier (e.g., `myapp`, `portal`, `api`)
> - **environment**: 3-character environment code (e.g., `dev`, `pro`, `qa`, `stg`)

**Examples of valid workspace names:**
```bash
# Development environment
terraform workspace new myapp-dev

# Production environment  
terraform workspace new myapp-pro

# QA environment
terraform workspace new portal-qa

# Staging environment
terraform workspace new api-stg
```

**Select an existing workspace:**
```bash
terraform workspace select myapp-dev
```

### 2. Create a Workspace-Specific Variables File

Create a variables file named after your **full workspace name** (including environment):

```bash
# For workspace 'myapp-dev'
touch myapp-dev.tfvars

# For workspace 'portal-pro'
touch portal-pro.tfvars

# For workspace 'api-qa'
touch api-qa.tfvars
```

Edit your workspace-specific `.tfvars` file. **Note:** The `applicationname` variable should match the application part of your workspace name:

```hcl
# Example for workspace 'myapp-dev'
applicationname                       = "myapp"    # Must match workspace prefix
location                              = "East US"
costmanagement                        = "your-cost-center"
owner                                 = "your-team"
db_admin_password                     = "YourSecurePassword123!"
user_assigned_identity_name           = "your-managed-identity"
user_assigned_identity_resource_group = "your-identity-rg"
environment                           = "your-environment" # e.g., Development, Production, QA

# Optional: If using Azure Container Registry
acr_name           = "youracrname"
acr_resource_group = "your-acr-rg"
n8n_image_tag      = "latest"
```

### 3. Deploy

**Always use the workspace-specific variable file pattern:**

```bash
terraform init
terraform plan -var-file="$(terraform workspace show).tfvars"
terraform apply -var-file="$(terraform workspace show).tfvars"
```

> **Best Practice:** This pattern automatically uses the correct variables file for your current workspace:
> - `myapp-dev` workspace → `myapp-dev.tfvars`
> - `myapp-pro` workspace → `myapp-pro.tfvars`
> - `portal-qa` workspace → `portal-qa.tfvars`

### 4. Access n8n

After deployment completes, access n8n at the URL shown in the `webapp_url` output:

```bash
terraform output webapp_url
```

---

## Configuration Variables

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `applicationname` | Application name for resource naming | - |
| `db_admin_password` | PostgreSQL admin password | - |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region | East US |
| `costmanagement` | Cost management tag | "" |
| `owner` | Owner tag | "" |
| `acr_name` | Azure Container Registry name | "" |
| `acr_resource_group` | ACR resource group | "" |
| `n8n_image_tag` | n8n Docker image tag | latest |
| `db_admin_username` | PostgreSQL admin username | n8nadmin |
| `user_assigned_identity_name` | Managed identity name | cpat-assistant-mi |
| `user_assigned_identity_resource_group` | Managed identity RG | oog-test-rg |

---

## Network Architecture

The deployment creates a **VNet** with three subnets:

| Subnet | CIDR | Purpose |
|--------|------|--------|
| App Subnet | 10.0.1.0/24 | Delegated to App Service, used for VNet integration |
| Private Endpoint Subnet | 10.0.2.0/24 | Hosts private endpoints, provides private access to web app |
| PostgreSQL Subnet | 10.0.3.0/24 | Delegated to PostgreSQL Flexible Server, private database access only |

---

## Security Features

✅ No public database access – PostgreSQL only accessible via private networking  
✅ HTTPS enforced – All web traffic uses TLS  
✅ Managed identity authentication – No stored credentials for ACR access  
✅ Private endpoints – Web app accessible via private IP  
✅ VNet integration – Outbound traffic routed through VNet  
✅ Private DNS zones – Internal name resolution  

---

## Cost Optimization

This configuration uses cost-effective SKUs suitable for development/testing:

- **App Service Plan:** B1 (Basic tier)  
- **PostgreSQL Server:** B_Standard_B1ms (Burstable tier)  
- **Storage:** 32GB (minimum)  
- **Backup retention:** 7 days  

> For production workloads, consider upgrading:  
> - App Service: S1 or P1V2 with `always_on = true`  
> - PostgreSQL: GP_Standard_D2s_v3 or higher  
> - Increased storage and backup retention  

---

## Environment Variables

Configured for n8n:

```env
DB_TYPE=postgresdb
N8N_PROTOCOL=https
NODE_ENV=production
N8N_ENCRYPTION_KEY=(auto-generated)
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
```

---

## Outputs

| Output | Description |
|--------|------------|
| `webapp_url` | Public URL for n8n web interface |
| `webapp_name` | App Service name |
| `postgres_fqdn` | PostgreSQL server FQDN |
| `private_endpoint_ip` | Private endpoint IP address |
| `vnet_name` | Virtual Network name |
| `user_assigned_identity_id` | Managed identity ID |
| `user_assigned_identity_principal_id` | Managed identity principal ID |

---

## Troubleshooting

### App Service Not Starting

Check App Service logs:

```bash
az webapp log tail --name {applicationname}-n8n --resource-group rg-{applicationname}-n8n
```

- Verify database connectivity from the App Service  
- Check managed identity has `AcrPull` permissions on ACR  

### Database Connection Issues

Ensure:

- VNet integration is properly configured  
- Private DNS zone is linked to VNet  
- PostgreSQL firewall allows VNet access  

### Workspace Validation Error

If you see `ERROR: You must use a named workspace` or workspace format errors:

```bash
# Check current workspace
terraform workspace show

# Create properly formatted workspace
terraform workspace new myapp-dev

# Switch to existing workspace
terraform workspace select myapp-dev
```

**Common workspace naming issues:**
- Using `default` workspace (not allowed)
- Environment code longer than 3 characters
- Environment code not in lowercase
- Missing hyphen separator
- Missing environment part

### Variable File Not Found

If you get variable file errors, ensure you're using the workspace-specific pattern:

```bash
# Check current workspace (should be format: applicationname-environment)
terraform workspace show

# Verify the .tfvars file exists (must match full workspace name)
ls -la $(terraform workspace show).tfvars

# If missing, create it with full workspace name
touch $(terraform workspace show).tfvars
```

**Example for workspace `myapp-dev`:**
```bash
# Current workspace
terraform workspace show
# Output: myapp-dev

# Required file name
ls -la myapp-dev.tfvars

# If missing
touch myapp-dev.tfvars
```

---

## Cleanup

To destroy all resources:

```bash
terraform destroy -var-file="$(terraform workspace show).tfvars"
```

> Note: Ensure you're in the correct workspace and using the matching variables file before destroying.

---

## Important Notes

- **Always use workspace-specific variable files** with the pattern `-var-file="$(terraform workspace show).tfvars"`
- **Workspace names must follow format:** `{applicationname}-{environment}` (e.g., `myapp-dev`)
- **Environment codes must be exactly 3 lowercase characters** (e.g., `dev`, `pro`, `qa`)
- **Application name in variables file must match workspace prefix**
- The `N8N_ENCRYPTION_KEY` is hardcoded in this example. For production, use **Azure Key Vault**.  
- Database password should be stored securely (Key Vault, environment variables).  
- Configuration prevents using the `default` workspace.  
- `always_on` is disabled to save costs; enable for production workloads.  

---

## License

This Terraform configuration is provided **as-is** for deployment purposes.

