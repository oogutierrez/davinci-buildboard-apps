# ---------------------------------------------------------------------------
# N8N Main App Outputs
# ---------------------------------------------------------------------------

output "n8n_fqdn" {
  value       = "${module.n8n_main.name}.${module.container_app_environment.default_domain}"
  description = "Base FQDN of the n8n Container App (without revision suffix)"
}

output "n8n_fqdn_with_revision" {
  value       = module.n8n_main.latest_revision_fqdn
  description = "Revision-specific FQDN of the n8n Container App (includes revision suffix like --abc123)"
}

output "n8n_url" {
  value       = "https://${module.n8n_main.name}.${module.container_app_environment.default_domain}"
  description = "Internal URL of the n8n web UI (using base FQDN)"
}

# ---------------------------------------------------------------------------
# N8N Runner Outputs
# ---------------------------------------------------------------------------

output "n8n_runner_fqdn" {
  value       = "${module.n8n_runner.name}.${module.container_app_environment.default_domain}"
  description = "Base FQDN of the n8n runner Container App (without revision suffix)"
}

output "n8n_runner_fqdn_with_revision" {
  value       = module.n8n_runner.latest_revision_fqdn
  description = "Revision-specific FQDN of the n8n runner Container App (includes revision suffix like --abc123)"
}

# ---------------------------------------------------------------------------
# N8N Web UI Outputs
# ---------------------------------------------------------------------------

output "n8n_webui_fqdn" {
  value       = "${module.n8n_webui.name}.${module.container_app_environment.default_domain}"
  description = "Base FQDN of the custom n8n web UI Container App (without revision suffix)"
}

output "n8n_webui_fqdn_with_revision" {
  value       = module.n8n_webui.latest_revision_fqdn
  description = "Revision-specific FQDN of the custom n8n web UI Container App (includes revision suffix like --abc123)"
}

output "n8n_webui_url" {
  value       = "https://${module.n8n_webui.name}.${module.container_app_environment.default_domain}"
  description = "Internal URL of the custom n8n web UI (using base FQDN)"
}

# ---------------------------------------------------------------------------
# Container App Environment Outputs
# ---------------------------------------------------------------------------

output "container_app_environment_name" {
  value       = module.container_app_environment.name
  description = "Container App Environment name"
}

output "container_app_environment_default_domain" {
  value       = module.container_app_environment.default_domain
  description = "Container App Environment default domain (used for internal FQDN construction)"
}

output "container_app_environment_static_ip" {
  value       = module.container_app_environment.static_ip_address
  description = "Static IP of the Container App Environment internal load balancer"
}

# ---------------------------------------------------------------------------
# PostgreSQL Outputs
# ---------------------------------------------------------------------------

output "postgres_fqdn" {
  value       = module.postgresql.server_fqdn
  description = "PostgreSQL server FQDN"
}

# ---------------------------------------------------------------------------
# Network Outputs
# ---------------------------------------------------------------------------

output "vnet_name" {
  value       = data.azurerm_virtual_network.existing_vnet.name
  description = "Virtual Network name"
}

# ---------------------------------------------------------------------------
# Managed Identity Outputs
# ---------------------------------------------------------------------------

output "user_assigned_identity_id" {
  value       = module.managed_identity.id
  description = "User-assigned managed identity ID"
  sensitive   = false
}

output "user_assigned_identity_principal_id" {
  value       = module.managed_identity.principal_id
  description = "User-assigned managed identity principal ID"
  sensitive   = true
}

output "user_assigned_identity_client_id" {
  value       = module.managed_identity.client_id
  description = "User-assigned managed identity client ID"
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Container Registry Outputs
# ---------------------------------------------------------------------------

output "acr_login_server" {
  value       = module.container_registry.login_server
  description = "ACR login server URL"
}

output "acr_name" {
  value       = module.container_registry.name
  description = "ACR name"
}

# ---------------------------------------------------------------------------
# Private Endpoint Outputs
# ---------------------------------------------------------------------------

# output "cae_private_endpoint_id" {
#   value       = azurerm_private_endpoint.cae_pe.id
#   description = "Resource ID of the Container App Environment private endpoint"
# }

# output "cae_private_endpoint_ip" {
#   value       = azurerm_private_endpoint.cae_pe.private_service_connection[0].private_ip_address
#   description = "Private IP address of the Container App Environment private endpoint"
# }

# ---------------------------------------------------------------------------
# Secret Outputs (Sensitive)
# ---------------------------------------------------------------------------

output "db_admin_password" {
  value       = local.db_password
  description = "PostgreSQL admin password (randomly generated if not provided)"
  sensitive   = true
}

output "runners_auth_token" {
  value       = local.runners_auth_token
  description = "N8N runners authentication token (randomly generated if not provided)"
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Hosts File Configuration Helper
# ---------------------------------------------------------------------------

output "hosts_file_entries" {
  value = <<-EOT

  # ========================================
  # N8N Container Apps - Hosts File Entries
  # ========================================
  # Add these entries to your hosts file:
  # Windows: C:\Windows\System32\drivers\etc\hosts
  # Linux/Mac: /etc/hosts
  # ========================================

  ${module.container_app_environment.static_ip_address}  ${module.n8n_main.name}.${module.container_app_environment.default_domain}
  ${module.container_app_environment.static_ip_address}  ${module.n8n_webui.name}.${module.container_app_environment.default_domain}

  # ========================================
  EOT
  description = "Ready-to-copy hosts file entries for local access (using base FQDN without revision suffix)"
}

# ---------------------------------------------------------------------------
# Post-Deployment Manual Steps Reminder
# ---------------------------------------------------------------------------

output "post_deployment_steps" {
  value = <<-EOT

  # ========================================================================================================
  # ⚠️  IMPORTANT: REQUIRED MANUAL CONFIGURATION STEPS
  # ========================================================================================================

  ✅ Step 1: Add TCP Port 5679 to N8N Main Container App

     The n8n-main container app requires port 5679 for runner communication.
     This MUST be configured manually via Azure Portal:

     1. Navigate to: Azure Portal → Container Apps
     2. Select: ${module.n8n_main.name}
     3. Go to: Settings → Ingress
     4. Under "Additional TCP Ports", add:
        - Port: 5679
        - Protocol: TCP
     5. Click Save

     Why: The task broker service listens on port 5679 for runner connections.
           The Terraform azurerm provider does not currently support configuring
           additional TCP ports via infrastructure-as-code.

  ========================================================================================================

  ✅ Step 2: Configure Your Hosts File for Local Access

     Run this command to get the entries:

       terraform output hosts_file_entries

     Then copy the entries to your hosts file:
     - Windows: C:\Windows\System32\drivers\etc\hosts (Run as Administrator)
     - Linux/Mac: /etc/hosts (Use sudo)

  ========================================================================================================

  📋 Quick Verification Commands:

     # Check Container Apps status
     az containerapp list --resource-group ${azurerm_resource_group.rg.name} --output table

     # View n8n-main ingress configuration
     az containerapp ingress show --name ${module.n8n_main.name} --resource-group ${azurerm_resource_group.rg.name}

  ========================================================================================================
  EOT
  description = "Important manual configuration steps required after deployment"
}
