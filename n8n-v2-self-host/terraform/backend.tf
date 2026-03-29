# Backend configuration for Terraform state storage
# State is stored in Azure Storage Account with locking support
#
# Usage:
#   terraform init -backend-config="backend.tfvars"
#
# Or use individual flags:
#   terraform init \
#     -backend-config="subscription_id=xxx" \
#     -backend-config="resource_group_name=xxx" \
#     -backend-config="storage_account_name=xxx" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=terraform.tfstate"

terraform {
  backend "azurerm" {
    # Backend configuration parameters:
    # - subscription_id      (required) Azure subscription ID for state storage
    # - resource_group_name  (required) Resource group containing storage account
    # - storage_account_name (required) Storage account name for state files
    # - container_name       (required) Blob container name
    # - key                  (required) State file name (e.g., "n8n/terraform.tfstate")
    #
    # These values should be provided via:
    # 1. backend.tfvars file (recommended for teams)
    # 2. Command-line flags (good for CI/CD)
    # 3. Environment variables (ARM_SUBSCRIPTION_ID, etc.)
    subscription_id      = "13d52521-10b9-4b99-91b7-a244d1a5a16b" # DAVINCI-DEV
    resource_group_name  = "rg-davinci-azuredevops-dev"
    storage_account_name = "davincidevn8nhosting"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
