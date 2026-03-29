# N8N Container Apps Architecture

## Visual Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Azure Subscription                              │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    Resource Group                                   │ │
│  │                                                                     │ │
│  │  ┌─────────────────┐                                               │ │
│  │  │  Managed        │◄──────────────────┐                           │ │
│  │  │  Identity       │                   │                           │ │
│  │  └────────┬────────┘                   │                           │ │
│  │           │                            │                           │ │
│  │           │ AcrPull                    │ Reader                    │ │
│  │           │                            │                           │ │
│  │  ┌────────▼────────┐         ┌────────┴────────┐                  │ │
│  │  │  Container      │         │  PostgreSQL      │                  │ │
│  │  │  Registry (ACR) │         │  Flexible Server │                  │ │
│  │  │  + Private EP   │         │  + Database      │                  │ │
│  │  └────────┬────────┘         └────────┬────────┘                  │ │
│  │           │                            │                           │ │
│  │           │ Pull Images                │ Connection                │ │
│  │           │                            │                           │ │
│  │  ┌────────▼────────────────────────────▼──────────────────────┐   │ │
│  │  │        Container App Environment (Internal)                │   │ │
│  │  │        + Private DNS Zone                                  │   │ │
│  │  │        + Wildcard DNS Record                              │   │ │
│  │  │        + Private Endpoint                                 │   │ │
│  │  │                                                           │   │ │
│  │  │   ┌──────────────┐    ┌──────────────┐   ┌────────────┐ │   │ │
│  │  │   │  N8N Main    │    │  N8N Runner  │   │  N8N WebUI │ │   │ │
│  │  │   │  Container   │◄───┤  Container   │   │  Container │ │   │ │
│  │  │   │              │    │              │   │            │ │   │ │
│  │  │   │  Port: 5678  │    │  (No Ingress)│   │ Port: 3000 │ │   │ │
│  │  │   │  Port: 5679  │    │              │   │            │ │   │ │
│  │  │   └──────┬───────┘    └──────────────┘   └─────┬──────┘ │   │ │
│  │  │          │                                      │        │   │ │
│  │  │          │ Proxies to                          │        │   │ │
│  │  │          └──────────────────────────────────────┘        │   │ │
│  │  └──────────────────────────────────────────────────────────┘   │ │
│  │                                                                  │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## Deployment Flow

### Phase 1: Foundation (Parallel)
```
┌──────────────────┐
│ Managed Identity │
└────────┬─────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ Container Registry + PostgreSQL        │
│ (Both depend on Identity)              │
└────────┬────────────────┬──────────────┘
         │                │
         ▼                ▼
   Import Images     Create Database
```

### Phase 2: Environment Setup
```
┌────────────────────────────────┐
│ Container App Environment      │
│  - Creates DNS Zone            │
│  - Links to VNet               │
│  - Creates Wildcard Record     │
│  - Configures Private Endpoint │
└────────────────┬───────────────┘
                 │
                 ▼
          Ready for Apps
```

### Phase 3: Core Apps (Parallel)
```
┌─────────────────┐     ┌─────────────────┐
│   N8N Main      │     │   N8N Runner    │
│   Container     │     │   Container     │
│                 │     │                 │
│ - Uses DB       │     │ - Connects to   │
│ - Exposes API   │     │   Main on 5679  │
│ - Broker on     │     │                 │
│   port 5679     │     │                 │
└────────┬────────┘     └────────┬────────┘
         │                       │
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
              Both Complete
```

### Phase 4: Web UI (Sequential - CRITICAL)
```
┌──────────────────────────────────┐
│ Wait for Main + Runner Complete  │
└────────────────┬─────────────────┘
                 │
                 ▼
         ┌───────────────┐
         │  N8N WebUI    │
         │  Container    │
         │               │
         │ - Proxies to  │
         │   N8N Main    │
         │ - User facing │
         └───────┬───────┘
                 │
                 ▼
### Phase 5: Private Endpoint (Final - CRITICAL)
```
┌──────────────────────────────────┐
│ Wait for All Apps Complete       │
└────────────────┬─────────────────┘
                 │
                 ▼
    ┌────────────────────────┐
    │ Container App Env      │
    │ Private Endpoint       │
    │                        │
    │ - Exposes environment  │
    │ - Final networking     │
    │ - After all apps ready │
    └────────────────────────┘
```

## Module Dependency Graph

```
terraform_data.workspace_validation
    │
    ├─► azurerm_resource_group.rg
    │       │
    │       ├─► module.managed_identity
    │       │       │
    │       │       ├─► module.container_registry
    │       │       │       ├─► null_resource.import_n8n_images
    │       │       │       └─► null_resource.import_webui_image
    │       │       │
    │       │       └─► module.postgresql
    │       │               └─► azurerm_postgresql_flexible_server_database
    │       │
    │       └─► module.container_app_environment
    │               ├─► azurerm_private_dns_zone
    │               ├─► azurerm_private_dns_zone_virtual_network_link
    │               ├─► azurerm_private_dns_a_record (wildcard)
    │               └─► azurerm_private_endpoint
    │
    ├─► module.n8n_main
    │       │
    │       └─► Depends on: container_registry, container_app_environment
    │
    ├─► module.n8n_runner
    │       │
    │       └─► Depends on: container_registry, container_app_environment
    │
    ├─► module.n8n_webui
    │       │
    │       └─► Depends on: n8n_main, n8n_runner, container_registry ⬅️ KEY!
    │
    └─► azurerm_private_endpoint.cae_pe ⬅️ CREATED LAST!
            │
            └─► Depends on: n8n_main, n8n_runner, n8n_webui ⬅️ ALL APPS READY!
```

## Network Architecture

### VNet Integration

```
┌────────────────────────────────────────────────────────────────┐
│                    Existing Virtual Network                     │
│                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐           │
│  │ private-subnet-01-pe │  │ private-subnet-01-app │           │
│  │ (Private Endpoints)  │  │ (Container Apps)      │           │
│  │                      │  │                       │           │
│  │  - ACR PE            │  │  - Delegated to      │           │
│  │  - CAE PE            │  │    Microsoft.App/    │           │
│  │                      │  │    environments      │           │
│  └──────────────────────┘  └──────────────────────┘           │
│                                                                 │
│  ┌──────────────────────────────────────┐                     │
│  │ private-subnet-01-postgres           │                     │
│  │ (PostgreSQL)                         │                     │
│  │                                      │                     │
│  │  - Delegated to                     │                     │
│  │    Microsoft.DBforPostgreSQL/       │                     │
│  │    flexibleServers                  │                     │
│  └──────────────────────────────────────┘                     │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### DNS Resolution Flow

```
Client in VNet
    │
    ├─► app1-n8n-webui.<environment-domain>
    │   └─► Wildcard DNS (*.<environment-domain>)
    │       └─► Container App Environment Static IP
    │           └─► Internal Load Balancer
    │               └─► N8N WebUI Container
    │
    └─► (WebUI proxies to)
        └─► app1-n8n.<environment-domain>
            └─► Same DNS resolution
                └─► N8N Main Container
```

## Security Architecture

### Identity and Access

```
┌──────────────────────────────────────────────────────────┐
│               User-Assigned Managed Identity              │
│                                                           │
│  ┌─────────────────┐         ┌────────────────────────┐ │
│  │ AcrPull Role    │         │ PostgreSQL Reader Role │ │
│  └────────┬────────┘         └───────────┬────────────┘ │
│           │                              │              │
│           ▼                              ▼              │
│   ┌────────────────┐           ┌──────────────────┐    │
│   │ Container      │           │  PostgreSQL      │    │
│   │ Registry       │           │  Server          │    │
│   └────────────────┘           └──────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
         │                                │
         │                                │
         ▼                                ▼
┌─────────────────┐            ┌──────────────────┐
│  N8N Main       │            │  N8N Runner      │
│  N8N WebUI      │            │                  │
└─────────────────┘            └──────────────────┘
```

### Secrets Management

```
┌────────────────────────────────────────────┐
│         Root Module (main.tf)              │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │  random_password.db_admin_password   │ │
│  │  random_password.runners_auth_token  │ │
│  └──────────────┬───────────────────────┘ │
│                 │                          │
│                 ▼                          │
│         locals.db_password                 │
│         locals.runners_auth_token          │
│                 │                          │
└─────────────────┼──────────────────────────┘
                  │
                  ├─► module.postgresql
                  │   └─► admin_password
                  │
                  ├─► module.n8n_main
                  │   └─► secrets[db-admin-password]
                  │   └─► secrets[runners-auth-token]
                  │
                  └─► module.n8n_runner
                      └─► secrets[runners-auth-token]
```

## Traffic Flow

### User Request Flow

```
1. User → VNet DNS Query
   └─► n8n-webui.<domain>

2. DNS Resolution
   └─► Wildcard A Record → Static IP

3. Internal Load Balancer
   └─► Routes to N8N WebUI Container

4. WebUI Proxies API Request
   └─► http://app1-n8n.<domain>/api

5. Internal DNS Resolution
   └─► Same wildcard → Same LB

6. Load Balancer Routes
   └─► N8N Main Container

7. N8N Main Processes
   └─► Queries PostgreSQL
   └─► Publishes to Task Broker (port 5679)

8. N8N Runner Subscribes
   └─► Connects to port 5679 on Main
   └─► Executes workflow tasks

9. Response Path
   └─► Main → WebUI → User
```

### Internal Communication

```
N8N Runner ──(Task Broker Protocol)──► N8N Main:5679
     │                                      │
     │                                      │
     └──(Uses same managed identity)───────┘
                      │
                      ▼
              Container Registry
```

## High Availability Considerations

### Scaling Configuration

```
┌───────────────────────────────────────────────────────┐
│ N8N Main                                              │
│  - min_replicas: 1                                    │
│  - max_replicas: 1                                    │
│  - Rationale: Single instance for task coordination   │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ N8N Runner                                            │
│  - min_replicas: 1                                    │
│  - max_replicas: 3                                    │
│  - Rationale: Horizontal scaling for task execution   │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ N8N WebUI                                             │
│  - min_replicas: 1                                    │
│  - max_replicas: 2                                    │
│  - Rationale: Basic HA for user-facing component      │
└───────────────────────────────────────────────────────┘
```

### Data Persistence

```
┌─────────────────────────────────────────┐
│ PostgreSQL Flexible Server              │
│  - Backup Retention: 7 days             │
│  - Geo-Redundant: Disabled (dev)        │
│  - Lifecycle Protection: Configurable   │
│  - Password Changes: Ignored            │
└─────────────────────────────────────────┘
```

## Cost Optimization

### Resource Sizing

| Component | Size | Justification |
|-----------|------|---------------|
| ACR | Premium | Required for private endpoints |
| PostgreSQL | B_Standard_B1ms | Suitable for small workloads |
| N8N Main | 1.0 CPU / 2Gi | Handles API + task broker |
| N8N Runner | 0.5 CPU / 1Gi | Lightweight task execution |
| WebUI | 0.5 CPU / 1Gi | Proxy + basic UI serving |

### Scaling Strategy

- **Scale Runners First** - Add runners before upgrading main
- **Monitor Task Queue** - Scale based on pending tasks
- **Database Growth** - Monitor storage, adjust as needed

## Disaster Recovery

### Backup Strategy

```
PostgreSQL
  └─► Automated Daily Backups (7 days retention)
  └─► Point-in-time restore capability
  └─► Manual backups before major changes

Container Images
  └─► Stored in ACR with geo-replication (optional)
  └─► Tagged by version for rollback

Terraform State
  └─► Stored in Azure Storage Account
  └─► State locking enabled
  └─► Versioning enabled
```

### Recovery Procedure

1. **Database Recovery**:
   ```bash
   az postgres flexible-server restore \
     --resource-group <rg> \
     --name <new-name> \
     --source-server <source> \
     --restore-time <timestamp>
   ```

2. **Application Rollback**:
   ```bash
   # Update image tag in tfvars
   n8n_image_tag = "previous-version"

   # Apply
   terraform apply -var-file="app1-dev.tfvars"
   ```

3. **Full Environment Rebuild**:
   ```bash
   # State is preserved in backend
   terraform destroy -var-file="app1-dev.tfvars"
   terraform apply -var-file="app1-dev.tfvars"
   ```

## Monitoring and Observability

### Recommended Metrics

- **Container Apps**: CPU, Memory, Request count, Response time
- **PostgreSQL**: Connections, Query duration, Storage used
- **ACR**: Pull requests, Storage usage

### Logging

- Container Apps → Azure Log Analytics
- PostgreSQL → Diagnostic Settings
- Application Logs → Container stdout/stderr

## Future Enhancements

1. **Auto-scaling Rules** - Based on CPU/memory metrics
2. **Azure Front Door** - Global load balancing
3. **Key Vault Integration** - Centralized secret management
4. **Application Insights** - Distributed tracing
5. **Geo-Replication** - Multi-region deployment
6. **Chaos Engineering** - Resilience testing

---

**Last Updated**: 2026-03-23
**Version**: 2.0 (Modular Architecture)
