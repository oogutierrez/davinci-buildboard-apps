# N8N Container Apps - Modular Terraform Deployment

A production-ready, modular Terraform configuration for deploying N8N workflow automation platform on Azure Container Apps with custom Web UI support.

## 🎯 Overview

This infrastructure-as-code (IaC) project deploys a complete N8N environment with:

- ✅ **N8N Main Application** - Core workflow engine with API and task broker
- ✅ **N8N Runners** - Scalable worker processes for task execution
- ✅ **Custom Web UI** - Optional front-end with proxy capabilities
- ✅ **PostgreSQL Database** - Persistent storage for workflows and settings
- ✅ **Azure Container Registry** - Private container image hosting
- ✅ **Full Network Isolation** - VNet integration with private endpoints
- ✅ **Managed Identity** - Azure RBAC for secure resource access

## 🏗️ Architecture Highlights

### Modular Design

The configuration is organized into **5 reusable modules** and a root orchestration layer:

```
modules/
├── managed-identity/          # User-assigned managed identity
├── container-registry/        # ACR with image imports
├── postgresql/                # Database server + database
├── container-app-environment/ # CAE with DNS configuration
└── container-app/             # Reusable app deployment module (used 3x)
```

### Key Features

1. **🔒 Security First**
   - All resources private (no public endpoints)
   - Managed Identity for service authentication
   - Random password generation for secrets
   - Sensitive outputs properly marked

2. **📦 Deployment Orchestration**
   - Proper dependency management
   - **WebUI deploys AFTER main + runner are complete** ✅
   - **Private endpoint created LAST after all apps** ✅
   - Parallel deployment where possible
   - Explicit dependencies where required

3. **🔧 Best Practices**
   - Modular, reusable components
   - Comprehensive variable validation
   - Lifecycle protection for critical resources
   - Backend state management
   - Workspace-based environment separation

4. **📈 Production Ready**
   - Health probes for containers
   - Auto-scaling configuration
   - Backup retention policies
   - Disaster recovery support

## 📁 Project Structure

```
n8n-v2-container-apps/
│
├── 📂 modules/                          # Reusable Terraform modules
│   ├── managed-identity/
│   ├── container-registry/
│   ├── postgresql/
│   ├── container-app-environment/
│   └── container-app/
│
├── 📄 main.tf                           # Root module (orchestrates everything)
├── 📄 variables.tf                      # Input variable definitions
├── 📄 outputs.tf                        # Output value definitions
├── 📄 versions.tf                       # Terraform & provider versions
├── 📄 backend.tf                        # Backend configuration (state storage)
│
├── 📄 terraform.tfvars.example          # ⭐ Input variables template (START HERE)
├── 📄 backend.tfvars.example            # Backend configuration template
├── 📄 app1-dev.tfvars                   # Example: environment-specific variables
├── 📄 app2-dev.tfvars                   # Example: environment-specific variables
│
├── 📚 QUICKSTART.md                     # Quick start deployment guide
├── 📚 MODULE_STRUCTURE.md               # Detailed module documentation
├── 📚 ARCHITECTURE.md                   # Architecture diagrams & flows
├── 📚 TERRAFORM_BEST_PRACTICES.md       # Best practices implemented
│
└── 📄 main-containerapps-customui.tf.old # Previous monolithic config (reference)
```

## 🚀 Quick Start

### Prerequisites

- Azure subscription with contributor access
- Terraform >= 1.5.0
- Azure CLI authenticated
- Existing VNet with required subnets:
  - Container Apps subnet (delegated, ≥ /27)
  - Private Endpoints subnet
  - PostgreSQL subnet (delegated)

### 5-Minute Deployment

```bash
# 1. Configure backend
cp backend.tfvars.example backend.tfvars
# Edit backend.tfvars with your Azure Storage details

# 2. Create your environment config
cp terraform.tfvars.example myapp-prod.tfvars
# Edit myapp-prod.tfvars with your values (see template for all options)

# 3. Initialize Terraform
terraform init -backend-config="backend.tfvars"

# 4. Create workspace
terraform workspace new myapp-prod

# 5. Plan deployment
terraform plan -var-file="myapp-prod.tfvars"

# 6. Deploy
terraform apply -var-file="myapp-prod.tfvars"

# 7. View required post-deployment steps
terraform output post_deployment_steps
```

**⏱️ Deployment Time**: ~15-20 minutes

**⚠️ Important**: After deployment, run `terraform output post_deployment_steps` to view required manual configuration steps.

See **[QUICKSTART.md](QUICKSTART.md)** for detailed step-by-step instructions.

## 🔑 Critical Design Decisions: Deployment Orchestration

### Challenge 1: WebUI Dependency Chain

In the original monolithic design, all three container apps (main, runner, webui) could deploy in parallel, leading to potential race conditions where the WebUI might start before the backend services were fully ready.

**Solution**: The modular design implements an **explicit dependency chain**:

```terraform
module "n8n_webui" {
  # ... configuration ...

  depends_on = [
    module.n8n_main,      # ⬅️ Wait for main app
    module.n8n_runner,    # ⬅️ Wait for runner
    module.container_registry
  ]
}
```

**Result**: WebUI deployment is **guaranteed** to start only after both n8n-main and n8n-runner are successfully deployed.

### Challenge 2: Private Endpoint Timing

Exposing the Container App Environment via private endpoint before all apps are ready could lead to incomplete or broken deployments being accessible.

**Solution**: Private endpoint is created **as the final step**:

```terraform
resource "azurerm_private_endpoint" "cae_pe" {
  # ... configuration ...

  depends_on = [
    module.n8n_main,
    module.n8n_runner,
    module.n8n_webui    # ⬅️ Wait for ALL apps!
  ]
}
```

**Result**: Environment is only exposed after all applications are fully deployed and operational.

### Why These Matter

1. **Prevents Startup Errors**: WebUI won't try to proxy to non-existent services
2. **Cleaner Deployments**: No retry loops or connection timeouts
3. **No Premature Exposure**: Private endpoint only created when ready
4. **Predictable Behavior**: Deployment order is deterministic
5. **Easier Troubleshooting**: Clear failure points vs. timing issues

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for detailed deployment flow diagrams.

## 📊 Resource Overview

| Resource | Module | Purpose |
|----------|--------|---------|
| Resource Group | Root | Container for all resources |
| User Managed Identity | managed-identity | Service authentication |
| Container Registry | container-registry | Private image storage |
| PostgreSQL Server | postgresql | Workflow data persistence |
| Container App Environment | container-app-environment | Hosting platform |
| N8N Main App | container-app | Core workflow engine |
| N8N Runner | container-app | Task execution workers |
| N8N WebUI | container-app | Custom front-end |
| Private Endpoints | Various | Network security |
| Private DNS Zones | container-app-environment | Internal name resolution |

**Total Resources**: ~30-35 depending on configuration

## 🔐 Security Features

### Network Isolation

- All resources deployed in private subnets
- No public IP addresses
- Private endpoints for ACR, PostgreSQL, and Container App Environment
- VNet integration with delegated subnets

### Identity & Access Management

- Azure Managed Identity (no stored credentials)
- Role-Based Access Control (RBAC)
  - `AcrPull` for container registry
  - `Reader` for PostgreSQL
- Least privilege principle

### Secrets Management

- Random password generation (no hardcoded secrets)
- Sensitive variables marked appropriately
- State file encrypted in Azure Storage
- Container secrets injected via environment
- `.gitignore` configured to exclude all `*.tfvars` files (except templates)

### Compliance

- Resource group deletion protection
- PostgreSQL lifecycle protection
- Audit logging enabled
- Tagging for cost management

## 🎛️ Configuration

### Configuration Template

A comprehensive configuration template is provided: **[terraform.tfvars.example](terraform.tfvars.example)**

Copy and customize this template for your deployment:
```bash
cp terraform.tfvars.example myapp-prod.tfvars
```

The template includes:
- ✅ All required and optional variables with descriptions
- ✅ Validation requirements and examples
- ✅ Commands to generate secure encryption keys
- ✅ Deployment checklist
- ✅ Post-deployment reminders

### Required Variables

```hcl
applicationname               = "myapp"        # Lowercase, alphanumeric, max 10 chars
subscription_id               = "xxx"
environment                   = "production"   # development|production|staging|qa

existing_vnet_name            = "my-vnet"
existing_vnet_resource_group  = "network-rg"
existing_app_subnet_name      = "container-apps"
existing_pe_subnet_name       = "private-endpoints"
existing_postgres_subnet_name = "postgres"

n8n_encryption_key            = "32-char-minimum-encryption-key"

costmanagement                = "CostCenter:12345"
owner                         = "team@company.com"
category                      = "Environment:Prod"
```

### Optional Variables (with auto-generation)

```hcl
db_admin_password    = ""  # Auto-generated if empty
runners_auth_token   = ""  # Auto-generated if empty
webui_image          = ""  # Import from external registry if provided
n8n_image_tag        = "latest"
webui_image_tag      = "latest"
```

See **[terraform.tfvars.example](terraform.tfvars.example)** for complete documentation with examples, or **[variables.tf](variables.tf)** for technical variable definitions.

## 📤 Outputs

After deployment, retrieve important information:

```bash
# ⚠️ IMPORTANT: View required manual steps
terraform output post_deployment_steps

# Hosts file entries (for local access)
terraform output hosts_file_entries

# Application URLs (internal to VNet)
terraform output n8n_url
terraform output n8n_webui_url

# Application FQDNs
terraform output n8n_fqdn
terraform output n8n_webui_fqdn

# Database connection
terraform output postgres_fqdn

# Container registry
terraform output acr_login_server

# Container App Environment details
terraform output container_app_environment_static_ip

# Generated secrets (sensitive)
terraform output -json db_admin_password
terraform output -json runners_auth_token
```

## ⚠️ Post-Deployment Configuration

### Required Manual Steps

After successful deployment, you must manually configure the following:

1. **N8N Main Container App - Add TCP Port 5679**

   The n8n-main container app requires port 5679 to be added as an additional TCP ingress port for runner communication:

   ```bash
   az containerapp ingress show \
     --name <applicationname>-n8n-main-<env> \
     --resource-group rg-<applicationname>-n8n-<env>
   ```

   Navigate to the Azure Portal:
   - Go to your n8n-main Container App
   - Settings → Ingress
   - Add additional port: **5679** (TCP)
   - Save changes

   **Why**: The task broker service listens on port 5679 for runner connections. This port cannot be configured via Terraform in the current azurerm provider.

2. **Configure Hosts File for Local Access**

   To access the n8n applications from your local computer, you need to add the FQDNs to your hosts file:

   **Get Ready-to-Copy Entries:**
   ```bash
   terraform output hosts_file_entries
   ```

   This will output formatted entries like:
   ```
   10.0.5.10  myapp-n8n-main-dev.internal-abc123.eastus.azurecontainerapps.io
   10.0.5.10  myapp-n8n-webui-dev.internal-abc123.eastus.azurecontainerapps.io
   ```

   **Edit your hosts file:**

   - **Windows**: `C:\Windows\System32\drivers\etc\hosts` (Run as Administrator)
   - **Linux/Mac**: `/etc/hosts` (Use sudo)

   Copy and paste the entries from the terraform output into your hosts file and save.

   **Why**: The applications use internal/private DNS names that are only resolvable within the Azure VNet. The hosts file allows your local browser to resolve these names to the Container App Environment's static IP address when connected via VPN or ExpressRoute.

## 🔄 Common Operations

### Update Application Version

```bash
# Edit tfvars
n8n_image_tag = "1.2.3"

# Apply
terraform apply -var-file="myapp-prod.tfvars"
```

### Scale Runners

Modify `main.tf`:
```terraform
module "n8n_runner" {
  max_replicas = 5  # Increase from 3
}
```

Then apply:
```bash
terraform apply -var-file="myapp-prod.tfvars"
```

### View Deployment State

```bash
terraform state list
terraform show
```

### Destroy Everything

```bash
terraform destroy -var-file="myapp-prod.tfvars"
```

**Note**: Protected resources (PostgreSQL with `prevent_destroy = true`) will prevent destruction.

## 📚 Documentation

Comprehensive documentation is available:

| Document | Description |
|----------|-------------|
| **[QUICKSTART.md](QUICKSTART.md)** | Step-by-step deployment guide |
| **[MODULE_STRUCTURE.md](MODULE_STRUCTURE.md)** | Detailed module documentation |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Architecture diagrams & flows |
| **[TERRAFORM_BEST_PRACTICES.md](TERRAFORM_BEST_PRACTICES.md)** | Best practices implemented |

## 🛠️ Development

### Module Testing

Test modules independently:

```bash
cd modules/container-app
terraform init
terraform plan
```

### Code Quality

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Generate dependency graph
terraform graph | dot -Tsvg > graph.svg
```

### Pre-commit Hooks

Recommended `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
```

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Module not found | Run `terraform init` |
| Workspace error | Create workspace: `terraform workspace new <name>` |
| Backend not configured | Run `terraform init -backend-config="backend.tfvars"` |
| Subnet delegation missing | Add delegation to subnet via Azure Portal or CLI |
| Image import fails | Verify Azure CLI authentication and permissions |

See **[QUICKSTART.md](QUICKSTART.md)** for detailed troubleshooting steps.

## 🎯 Roadmap

Future enhancements:

- [ ] Module versioning and registry
- [ ] Automated testing with Terratest
- [ ] Multi-region deployment support
- [ ] Azure Monitor integration module
- [ ] Key Vault integration for secrets
- [ ] CI/CD pipeline templates
- [ ] Backup automation module
- [ ] Cost optimization recommendations

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests (if applicable)
5. Update documentation
6. Submit a pull request

## 📝 License

[Your License Here]

## 👥 Authors

- **Original Implementation**: [Your Name]
- **Modular Refactoring**: Claude Code (Anthropic)

## 🙏 Acknowledgments

- N8N community for the excellent workflow automation platform
- HashiCorp for Terraform
- Microsoft Azure for the cloud platform

## 📞 Support

For issues, questions, or contributions:

- Create an issue in the repository
- Review existing documentation
- Check Azure and Terraform official docs

---

**Version**: 2.0 (Modular Architecture)
**Last Updated**: 2026-03-23

**Ready to deploy? See [QUICKSTART.md](QUICKSTART.md) to get started!** 🚀
