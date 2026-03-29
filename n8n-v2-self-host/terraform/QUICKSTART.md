# Quick Start Guide - Modular N8N Deployment

This guide will help you deploy the N8N Container Apps infrastructure using the new modular structure.

## Prerequisites

✅ Azure subscription with appropriate permissions
✅ Terraform >= 1.5.0 installed
✅ Azure CLI installed and authenticated
✅ Existing VNet with required subnets:
  - Container Apps subnet (delegated to Microsoft.App/environments, at least /27)
  - Private Endpoints subnet
  - PostgreSQL subnet (delegated to Microsoft.DBforPostgreSQL/flexibleServers)
✅ Existing Private DNS zones for ACR and PostgreSQL in DAVINCI-PRO subscription

## Step-by-Step Deployment

### 1. Clone/Navigate to Repository

```bash
cd c:\Users\GuOr414\Documents\CPaT\Terraform\n8n-v2-container-apps
```

### 2. Configure Backend

The backend configuration is defined in `backend.tf`. You need to provide the values via `backend.tfvars`:

```bash
cp backend.tfvars.example backend.tfvars
```

Edit `backend.tfvars` with your Azure Storage Account details:

```hcl
subscription_id      = "your-subscription-id"
resource_group_name  = "your-state-rg"
storage_account_name = "yourstorageaccount"
container_name       = "tfstate"
key                  = "n8n/terraform.tfstate"
```

**Note**: The backend configuration is in a dedicated `backend.tf` file, separate from provider configuration.

### 3. Create Environment Variables File

Copy the template and customize for your environment:

```bash
cp terraform.tfvars.example myapp-prod.tfvars
```

Edit `myapp-prod.tfvars` and fill in all REQUIRED fields. The template includes:

**Required Fields:**
- `subscription_id` - Your Azure subscription ID
- `applicationname` - App identifier (lowercase, max 10 chars)
- `location` - Azure region
- `environment` - development, production, staging, or qa
- `existing_vnet_name` and related network configuration
- `n8n_encryption_key` - Minimum 32 characters (generate with `openssl rand -base64 48`)
- `costmanagement`, `owner`, `category` - Resource tags

**Optional Fields (with smart defaults):**
- `db_admin_password` - Leave empty to auto-generate
- `runners_auth_token` - Leave empty to auto-generate
- `n8n_image_tag` - Defaults to "latest"
- `webui_*` - Custom web UI configuration
- `prevent_postgres_destroy` - Set true for production

**Quick Example:**
```hcl
applicationname               = "myapp"
subscription_id               = "12345678-1234-1234-1234-123456789abc"
environment                   = "production"
existing_vnet_name            = "prod-vnet"
existing_vnet_resource_group  = "network-rg"
existing_app_subnet_name      = "container-apps-subnet"
existing_pe_subnet_name       = "private-endpoints-subnet"
existing_postgres_subnet_name = "postgres-subnet"
n8n_encryption_key            = "k9mP2vL8nQ4wX7jR5tY3bN6hF1dG8sA9cE2zM5xK7pW4qV6uT3yH9rJ2nL5mB8fD"
costmanagement                = "CostCenter:12345+Project:N8N"
owner                         = "team@company.com"
category                      = "Environment:Production+Criticality:High"
prevent_postgres_destroy      = true
```

See the [terraform.tfvars.example](terraform.tfvars.example) file for complete documentation of all variables.

### 4. Initialize Terraform

```bash
terraform init -backend-config="backend.tfvars"
```

Expected output:
```
Initializing modules...
- managed_identity in modules/managed-identity
- container_registry in modules/container-registry
- postgresql in modules/postgresql
- container_app_environment in modules/container-app-environment
- container_app in modules/container-app
...
Terraform has been successfully initialized!
```

### 5. Create Workspace

Use workspaces to separate environments:

```bash
# Create new workspace
terraform workspace new myapp-prod

# Or select existing workspace
terraform workspace select myapp-prod

# Verify
terraform workspace show
```

### 6. Plan Deployment

```bash
terraform plan -var-file="myapp-prod.tfvars" -out=tfplan
```

Review the plan carefully. You should see:
- ~30 resources to create
- Module instantiations for all 5 modules
- 3 container apps (main, runner, webui)

### 7. Apply Configuration

```bash
terraform apply tfplan
```

This will deploy in the following order:
1. Resource Group
2. Managed Identity
3. Container Registry + PostgreSQL (parallel)
4. Container App Environment
5. N8N Main + N8N Runner (parallel)
6. N8N WebUI (waits for main and runner)

Deployment typically takes **15-20 minutes**.

### 8. Retrieve Outputs and View Post-Deployment Steps

After successful deployment:

```bash
# ⚠️ IMPORTANT: View required manual configuration steps
terraform output post_deployment_steps

# View all outputs
terraform output

# Get hosts file entries (important for local access)
terraform output hosts_file_entries

# Get application URLs
terraform output n8n_url
terraform output n8n_webui_url

# Get sensitive outputs (passwords)
terraform output -json db_admin_password
terraform output -json runners_auth_token
```

**The `post_deployment_steps` output provides detailed instructions for:**
1. Adding TCP port 5679 to the n8n-main container app
2. Configuring your local hosts file for browser access
3. Quick verification commands

### 9. Verify Deployment

```bash
# Check Container Apps
az containerapp list \
  --resource-group rg-myapp-n8n-pro \
  --output table

# Check health of main app
az containerapp show \
  --name myapp-n8n \
  --resource-group rg-myapp-n8n-pro \
  --query properties.runningStatus
```

### 10. Configure Additional TCP Port (REQUIRED)

**IMPORTANT**: You must manually add port 5679 to the n8n-main container app ingress:

```bash
# View current ingress configuration
az containerapp ingress show \
  --name myapp-n8n-main-pro \
  --resource-group rg-myapp-n8n-pro \
  --query "{targetPort:targetPort,exposedPort:exposedPort,additionalPorts:additionalPortMappings}" \
  --output table
```

**Manual Steps (Azure Portal)**:
1. Navigate to Azure Portal → Container Apps
2. Select your n8n-main container app (e.g., `myapp-n8n-main-pro`)
3. Go to **Settings** → **Ingress**
4. Under **Additional TCP Ports**, add:
   - **Port**: 5679
   - **Protocol**: TCP
5. Click **Save**

**Why this is required**: Port 5679 is used by the n8n task broker service for communication with runners. This port must be exposed for the runner instances to connect to the main app. The current Terraform azurerm provider does not support configuring additional TCP ports via code.

### 11. Configure Local Hosts File for Browser Access

**IMPORTANT**: To access the applications from your local computer, add the FQDNs to your hosts file.

**Quick Method: Get Ready-to-Copy Entries**

```bash
# Get formatted hosts file entries
terraform output hosts_file_entries
```

This will output ready-to-copy entries like:
```
10.0.5.10  myapp-n8n-main-pro.internal-abc123.eastus.azurecontainerapps.io
10.0.5.10  myapp-n8n-webui-pro.internal-abc123.eastus.azurecontainerapps.io
```

**Manual Method: Get Individual Values**

```bash
# Get the static IP
terraform output container_app_environment_static_ip

# Get n8n main FQDN
terraform output n8n_fqdn

# Get n8n webui FQDN
terraform output n8n_webui_fqdn
```

**Step 1: Edit Hosts File**

Open your hosts file with administrator/root privileges:

**Windows:**
```powershell
# Run as Administrator
notepad C:\Windows\System32\drivers\etc\hosts
```

**Linux/Mac:**
```bash
sudo nano /etc/hosts
```

**Step 2: Add Entries**

Copy the entries from the `terraform output hosts_file_entries` command above and paste them into your hosts file.

Save the file and close the editor.

**Step 3: Verify DNS Resolution**

```bash
# Windows
ping myapp-n8n-webui-pro.internal-abc123.eastus.azurecontainerapps.io

# Linux/Mac
ping -c 4 myapp-n8n-webui-pro.internal-abc123.eastus.azurecontainerapps.io
```

You should see the private IP address you configured.

**Why this is required**: The Container Apps use internal/private DNS names that are only resolvable within the Azure VNet. The hosts file allows your local computer to resolve these names to the Container App Environment's private endpoint IP address, enabling browser access over VPN or ExpressRoute.

### 12. Access Application

From a VM or resource within the VNet:

```bash
# Access N8N via Web UI
curl -k https://myapp-n8n-webui.<environment-domain>

# Direct access to N8N API
curl -k https://myapp-n8n.<environment-domain>/healthz
```

## Directory Structure After Initialization

```
n8n-v2-container-apps/
├── .terraform/              # Terraform working directory (git-ignored)
├── modules/                 # Reusable modules
│   ├── managed-identity/
│   ├── container-registry/
│   ├── postgresql/
│   ├── container-app-environment/
│   └── container-app/
├── main.tf                  # Root module orchestration
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── versions.tf              # Provider and version requirements
├── backend.tfvars           # Backend configuration (git-ignored)
├── myapp-prod.tfvars        # Environment variables
└── tfplan                   # Saved plan (git-ignored)
```

## Common Operations

### Update Application Version

1. Edit tfvars:
   ```hcl
   n8n_image_tag = "1.2.3"
   ```

2. Apply changes:
   ```bash
   terraform apply -var-file="myapp-prod.tfvars"
   ```

### Scale Runners

1. Modify the runner configuration in `main.tf`:
   ```hcl
   module "n8n_runner" {
     # ...
     max_replicas = 5  # Increase from 3
   }
   ```

2. Apply:
   ```bash
   terraform apply -var-file="myapp-prod.tfvars"
   ```

### View State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.n8n_main.azurerm_container_app.app
```

### Import Existing Resources

If you have existing resources to import:

```bash
terraform import \
  'module.postgresql.azurerm_postgresql_flexible_server.postgres' \
  /subscriptions/.../resourceGroups/.../providers/Microsoft.DBforPostgreSQL/flexibleServers/...
```

## Troubleshooting

### Issue: Module Not Found

**Error**: `Module not found: modules/container-app`

**Solution**:
```bash
terraform init
```

### Issue: Workspace Conflict

**Error**: `Workspace "default" is not allowed`

**Solution**:
```bash
terraform workspace new myapp-prod
```

### Issue: Backend Not Configured

**Error**: `Backend configuration required`

**Solution**:
```bash
terraform init -backend-config="backend.tfvars"
```

### Issue: Image Import Fails

**Error**: `az acr import failed`

**Solution**:
1. Verify Azure CLI is authenticated:
   ```bash
   az account show
   ```
2. Ensure you have permission to import images
3. Check network connectivity to docker.io

### Issue: Subnet Delegation Missing

**Error**: `Subnet must be delegated to Microsoft.App/environments`

**Solution**:
```bash
az network vnet subnet update \
  --resource-group <vnet-rg> \
  --vnet-name <vnet-name> \
  --name <subnet-name> \
  --delegations Microsoft.App/environments
```

### Issue: WebUI Won't Start

**Symptoms**: N8N Main and Runner are running, but WebUI is stuck

**Check Dependencies**:
```bash
terraform graph | dot -Tsvg > graph.svg
```

Look for dependency chain to webui.

**Solution**:
The modular structure ensures webui depends on both main and runner. If stuck:
1. Check container logs:
   ```bash
   az containerapp logs show \
     --name myapp-n8n-webui \
     --resource-group rg-myapp-n8n-pro
   ```
2. Verify network connectivity between webui and main
3. Check health probe configuration

## Security Best Practices

### 0. Protect Your Configuration Files

**IMPORTANT**: The `.gitignore` file is configured to exclude all `*.tfvars` files from version control.

```bash
# Verify your tfvars files are ignored
git status

# Your environment-specific tfvars should NOT appear in git status
# Only *.tfvars.example files should be tracked
```

Never commit files containing:
- Subscription IDs
- Encryption keys
- Passwords or tokens
- Production configuration

### 1. Secrets Management

**Don't**: Store secrets in tfvars files committed to git
**Do**: Use environment variables or Azure Key Vault

```bash
export TF_VAR_db_admin_password="$(az keyvault secret show --name db-password --vault-name myvault --query value -o tsv)"
export TF_VAR_n8n_encryption_key="$(az keyvault secret show --name n8n-key --vault-name myvault --query value -o tsv)"

terraform apply -var-file="myapp-prod.tfvars"
```

### 2. State File Security

- Store state in Azure Storage with encryption
- Enable state locking
- Limit access with RBAC
- Use Managed Identity for Terraform

### 3. Network Security

- Keep all resources internal (no public IPs)
- Use Private Endpoints for all services
- Implement NSGs on subnets
- Use Azure Firewall for egress control

### 4. Resource Protection

For production:
```hcl
prevent_postgres_destroy = true
```

In modules, add lifecycle blocks:
```hcl
lifecycle {
  prevent_destroy = true
}
```

## Maintenance

### Regular Updates

```bash
# Update providers
terraform init -upgrade

# Plan with no changes (validation)
terraform plan -var-file="myapp-prod.tfvars"
```

### Backup Before Changes

```bash
# Backup state
terraform state pull > backup-$(date +%Y%m%d).tfstate

# Backup database
az postgres flexible-server backup create \
  --resource-group rg-myapp-n8n-pro \
  --name psql-myapp-n8n
```

### Clean Up

To destroy everything:

```bash
# Review what will be destroyed
terraform plan -destroy -var-file="myapp-prod.tfvars"

# Destroy (with caution!)
terraform destroy -var-file="myapp-prod.tfvars"
```

**Warning**: Database will be protected if `prevent_postgres_destroy = true`.

## Next Steps

1. **Configure Monitoring**: Set up Azure Monitor alerts
2. **Enable Backups**: Configure automated PostgreSQL backups
3. **Set Up CI/CD**: Automate deployments with Azure DevOps or GitHub Actions
4. **Security Hardening**: Implement Azure Policy and Security Center
5. **Documentation**: Document your specific configuration and runbooks

## Getting Help

- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **Module Structure**: See [MODULE_STRUCTURE.md](MODULE_STRUCTURE.md)
- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Best Practices**: See [TERRAFORM_BEST_PRACTICES.md](TERRAFORM_BEST_PRACTICES.md)

## Quick Reference

| Command | Purpose |
|---------|---------|
| `terraform init` | Initialize working directory |
| `terraform plan` | Preview changes |
| `terraform apply` | Apply changes |
| `terraform destroy` | Destroy infrastructure |
| `terraform output` | View outputs |
| `terraform state list` | List resources |
| `terraform workspace list` | List workspaces |
| `terraform fmt` | Format code |
| `terraform validate` | Validate configuration |

---

**Ready to deploy? Start with Step 1!** 🚀
