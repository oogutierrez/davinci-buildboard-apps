# Backend Configuration Guide

This document explains the Terraform backend configuration for state management.

## Overview

The Terraform backend configuration is defined in a dedicated **`backend.tf`** file, separate from provider configuration. This follows best practices for clear separation of concerns.

## File Structure

```
n8n-v2-container-apps/
├── backend.tf                 # Backend configuration (declares backend type)
├── backend.tfvars.example     # Example backend values
├── backend.tfvars            # Your backend values (git-ignored)
└── versions.tf               # Provider and Terraform version requirements
```

## Backend Configuration Files

### backend.tf

This file declares the backend type and documents required parameters:

```terraform
terraform {
  backend "azurerm" {
    # Configuration provided via backend.tfvars or CLI flags
  }
}
```

**Purpose**:
- Declares Azure Storage backend
- Documents required parameters
- Version controlled (committed to git)

### backend.tfvars (User-Created)

This file contains your actual backend values:

```hcl
subscription_id      = "13d52521-10b9-4b99-91b7-a244d1a5a16b"
resource_group_name  = "rg-davinci-azuredevops-dev"
storage_account_name = "davincidevn8nhosting"
container_name       = "tfstate"
key                  = "n8n/terraform.tfstate"
```

**Purpose**:
- Contains actual backend values
- **Should be git-ignored** (sensitive information)
- Used at `terraform init` time

### backend.tfvars.example

Template file for team members:

```hcl
# Backend configuration for Terraform state
# Copy this file to backend.tfvars and update with your values
# Usage: terraform init -backend-config="backend.tfvars"

subscription_id      = "your-subscription-id"
resource_group_name  = "your-state-rg"
storage_account_name = "yourstorageaccount"
container_name       = "tfstate"
key                  = "terraform.tfstate"
```

**Purpose**:
- Template for new users
- Version controlled (committed to git)
- Shows required parameters

## Usage

### Initial Setup

1. **Copy the example file**:
   ```bash
   cp backend.tfvars.example backend.tfvars
   ```

2. **Edit with your values**:
   ```bash
   nano backend.tfvars
   # Or use your preferred editor
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init -backend-config="backend.tfvars"
   ```

### Subsequent Initializations

If backend configuration changes, reinitialize:

```bash
terraform init -reconfigure -backend-config="backend.tfvars"
```

## Alternative Configuration Methods

### Method 1: backend.tfvars (Recommended)

Best for team environments:

```bash
terraform init -backend-config="backend.tfvars"
```

**Pros**:
- All values in one file
- Easy to share template
- Consistent across team

**Cons**:
- File must be git-ignored
- Each developer needs to create it

### Method 2: Individual Flags

Good for CI/CD pipelines:

```bash
terraform init \
  -backend-config="subscription_id=xxx" \
  -backend-config="resource_group_name=xxx" \
  -backend-config="storage_account_name=xxx" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=terraform.tfstate"
```

**Pros**:
- No files to manage
- Good for automation

**Cons**:
- Verbose
- Easy to make mistakes

### Method 3: Environment Variables

Uses Azure CLI defaults:

```bash
export ARM_SUBSCRIPTION_ID="xxx"
export ARM_RESOURCE_GROUP="xxx"
# ... etc

terraform init -backend-config="storage_account_name=xxx" \
                -backend-config="container_name=tfstate" \
                -backend-config="key=terraform.tfstate"
```

**Pros**:
- Leverages Azure CLI authentication
- Secure (no files)

**Cons**:
- Must set environment variables
- Less discoverable for team

### Method 4: Hardcoded (Not Recommended)

Hardcoding values in backend.tf:

```terraform
terraform {
  backend "azurerm" {
    subscription_id      = "xxx"  # DON'T DO THIS
    resource_group_name  = "xxx"
    storage_account_name = "xxx"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
```

**Why not?**:
- ❌ Sensitive data in version control
- ❌ Hard to manage multiple environments
- ❌ Security risk
- ❌ Not flexible

## Backend Storage Account Setup

### Prerequisites

Your Azure Storage Account must have:

1. **Blob container** for state files
2. **Access control** configured
3. **Soft delete** enabled (recommended)
4. **Versioning** enabled (recommended)

### Create Backend Storage (Azure CLI)

```bash
# Variables
RG_NAME="rg-terraform-state"
LOCATION="eastus"
STORAGE_NAME="tfstatexxxxx"  # Must be globally unique
CONTAINER_NAME="tfstate"

# Create resource group
az group create --name $RG_NAME --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob \
  --https-only true \
  --allow-blob-public-access false

# Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_NAME \
  --auth-mode login

# Enable versioning
az storage account blob-service-properties update \
  --account-name $STORAGE_NAME \
  --resource-group $RG_NAME \
  --enable-versioning true

# Enable soft delete
az storage account blob-service-properties update \
  --account-name $STORAGE_NAME \
  --resource-group $RG_NAME \
  --enable-delete-retention true \
  --delete-retention-days 30
```

## State File Organization

### Single Environment

```
container: tfstate
key: terraform.tfstate
```

### Multiple Environments

Use different keys per environment:

```
container: tfstate
keys:
  - dev/terraform.tfstate
  - staging/terraform.tfstate
  - prod/terraform.tfstate
```

Or use workspaces:

```
container: tfstate
key: terraform.tfstate
workspaces:
  - app1-dev
  - app1-prod
  - app2-dev
```

### Multiple Projects

Use different containers or keys:

```
containers:
  - tfstate-n8n
  - tfstate-webapp
  - tfstate-database

# Or same container, different keys:
container: tfstate
keys:
  - n8n/dev/terraform.tfstate
  - n8n/prod/terraform.tfstate
  - webapp/dev/terraform.tfstate
  - webapp/prod/terraform.tfstate
```

## Security Best Practices

### 1. Access Control

Use RBAC to limit who can access state:

```bash
# Grant access to storage account
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee user@company.com \
  --scope "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Storage/storageAccounts/xxx"
```

### 2. Encryption

Enable encryption at rest (enabled by default):

```bash
az storage account update \
  --name $STORAGE_NAME \
  --resource-group $RG_NAME \
  --encryption-services blob
```

### 3. Network Security

Restrict network access:

```bash
az storage account update \
  --name $STORAGE_NAME \
  --resource-group $RG_NAME \
  --default-action Deny \
  --bypass AzureServices
```

Then add allowed IP ranges or VNet rules.

### 4. State Locking

Azure Storage backend automatically provides state locking via blob leases. No additional configuration needed!

### 5. Audit Logging

Enable diagnostic settings:

```bash
az monitor diagnostic-settings create \
  --name tfstate-audit \
  --resource "/subscriptions/xxx/.../storageAccounts/$STORAGE_NAME" \
  --logs '[{"category": "StorageRead", "enabled": true}, {"category": "StorageWrite", "enabled": true}]' \
  --workspace "/subscriptions/xxx/.../workspaces/xxx"
```

## Troubleshooting

### Error: Backend Configuration Changed

**Error**:
```
Error: Backend configuration changed
```

**Solution**:
```bash
terraform init -reconfigure -backend-config="backend.tfvars"
```

### Error: Failed to Get Existing Workspaces

**Error**:
```
Error: Failed to get existing workspaces: storage: service returned error:
StatusCode=403, ErrorCode=AuthorizationPermissionMismatch
```

**Solution**:
- Verify Azure CLI authentication: `az account show`
- Check RBAC permissions on storage account
- Ensure you have "Storage Blob Data Contributor" role

### Error: Backend Initialization Required

**Error**:
```
Backend initialization required: please run "terraform init"
```

**Solution**:
```bash
terraform init -backend-config="backend.tfvars"
```

### Error: State Lock

**Error**:
```
Error acquiring the state lock: Error message: "state blob is already locked"
```

**Solution**:
```bash
# List locks
az storage blob show \
  --account-name $STORAGE_NAME \
  --container-name tfstate \
  --name terraform.tfstate \
  --query lease

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

## Migration from Other Backends

### From Local State

```bash
# 1. Backup current state
terraform state pull > backup.tfstate

# 2. Add backend.tf (already done in this project)

# 3. Initialize with new backend
terraform init -backend-config="backend.tfvars"

# 4. Terraform will prompt to migrate state - answer 'yes'
```

### From Different Azure Storage

```bash
# 1. Update backend.tfvars with new values

# 2. Reconfigure backend
terraform init -reconfigure -backend-config="backend.tfvars"

# 3. Migrate state when prompted
```

## Best Practices Summary

✅ **DO**:
- Use backend.tfvars for values (git-ignored)
- Keep backend.tf simple and declarative
- Enable versioning on storage account
- Enable soft delete for recovery
- Use RBAC for access control
- Use separate state files per environment

❌ **DON'T**:
- Hardcode values in backend.tf
- Commit backend.tfvars to version control
- Share state files across unrelated projects
- Disable state locking
- Use same key for dev and prod

## Related Documentation

- [Terraform Backend Documentation](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure Storage Documentation](https://docs.microsoft.com/en-us/azure/storage/)
- [QUICKSTART.md](QUICKSTART.md) - For deployment instructions
- [MODULE_STRUCTURE.md](MODULE_STRUCTURE.md) - For project structure

---

**Last Updated**: 2026-03-23
**Version**: 2.0 (Modular Architecture)
