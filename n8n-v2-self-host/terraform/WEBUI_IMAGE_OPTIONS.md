# Web UI Image Configuration Options

This document explains the different ways to provide a custom web UI image for the N8N deployment.

## Overview

The container registry module supports **three options** for the web UI image:

1. **Import from External Registry** - Pull a pre-built image from Docker Hub or another registry
2. **Build from Dockerfile** - Build a custom image using Azure Container Registry Build
3. **Push Directly to ACR** - Push via CI/CD pipeline (no Terraform involvement)

## Option 1: Import from External Registry

Use this when you have a pre-built image in Docker Hub or another container registry.

### Configuration

```hcl
# In your .tfvars file
webui_image     = "docker.io/yourorg/n8n-webui:1.0.0"
webui_image_tag = "1.0.0"
```

### How It Works

- Terraform will use `az acr import` to pull the image into your private ACR
- Image will be tagged as `n8n-webui:${webui_image_tag}` in ACR
- No Docker build process - just imports existing image

### Example

```hcl
applicationname = "myapp"
environment     = "production"

# Import from Docker Hub
webui_image     = "docker.io/mycompany/n8n-custom-ui:2.1.0"
webui_image_tag = "2.1.0"
```

**Result**: Image available as `acrXXX.azurecr.io/n8n-webui:2.1.0`

---

## Option 2: Build from Dockerfile (New!)

Use this when you have a local Dockerfile that you want ACR to build.

### Configuration

```hcl
# In your .tfvars file
webui_dockerfile_path = "./webui-docker/Dockerfile"
webui_build_context   = "./webui-docker"  # Optional, defaults to Dockerfile directory
webui_image_tag       = "latest"
```

### How It Works

- Terraform will use `az acr build` to build your Dockerfile in Azure
- Build happens server-side in ACR (no local Docker daemon needed)
- Image will be tagged as `n8n-webui:${webui_image_tag}` in ACR

### Directory Structure

```
n8n-v2-container-apps/
├── main.tf
├── variables.tf
├── app1-dev.tfvars
└── webui-docker/              # Your custom web UI directory
    ├── Dockerfile
    ├── package.json
    ├── src/
    │   ├── index.js
    │   └── ...
    └── public/
```

### Example tfvars

```hcl
applicationname = "myapp"
environment     = "development"

# Build from local Dockerfile
webui_dockerfile_path = "./webui-docker/Dockerfile"
webui_build_context   = "./webui-docker"
webui_image_tag       = "dev-20260323"
```

### Dockerfile Path Options

**Relative to Terraform root**:
```hcl
webui_dockerfile_path = "./webui-docker/Dockerfile"
webui_dockerfile_path = "../shared/webui/Dockerfile"
```

**Absolute path**:
```hcl
webui_dockerfile_path = "c:/projects/n8n-webui/Dockerfile"
webui_dockerfile_path = "/home/user/n8n-webui/Dockerfile"
```

### Build Context

The build context is the directory sent to ACR for building. It should contain:
- The Dockerfile
- All files referenced in the Dockerfile (COPY, ADD commands)

**Auto-detect** (recommended):
```hcl
# Leave empty - will use Dockerfile's directory
webui_dockerfile_path = "./webui-docker/Dockerfile"
webui_build_context   = ""  # Auto-detects to ./webui-docker
```

**Explicit context**:
```hcl
# Specify different context (if Dockerfile references parent directory files)
webui_dockerfile_path = "./webui-docker/Dockerfile"
webui_build_context   = "."  # Uses Terraform root as context
```

**Result**: Image available as `acrXXX.azurecr.io/n8n-webui:dev-20260323`

---

## Option 3: Push Directly to ACR

Use this when your CI/CD pipeline handles building and pushing the image.

### Configuration

```hcl
# In your .tfvars file - leave both empty
webui_image           = ""  # Don't import
webui_dockerfile_path = ""  # Don't build
webui_image_tag       = "latest"
```

### How It Works

1. Your CI/CD pipeline builds the image
2. Pipeline pushes to ACR as `n8n-webui:${tag}`
3. Terraform uses the existing image (no import or build)

### Example GitHub Actions Workflow

```yaml
name: Build and Push Web UI

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Login to ACR
        run: |
          az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} -p ${{ secrets.AZURE_CLIENT_SECRET }} --tenant ${{ secrets.AZURE_TENANT_ID }}
          az acr login --name acrXXXn8ndev

      - name: Build and Push
        run: |
          docker build -t acrXXXn8ndev.azurecr.io/n8n-webui:${{ github.sha }} ./webui-docker
          docker push acrXXXn8ndev.azurecr.io/n8n-webui:${{ github.sha }}
```

Then in your tfvars:
```hcl
webui_image_tag = "abc123def"  # Your commit SHA or version
```

---

## Comparison

| Method | Pros | Cons | Use Case |
|--------|------|------|----------|
| **Import from Registry** | Simple, fast, uses existing image | Requires external registry access | Pre-built images from Docker Hub |
| **Build from Dockerfile** | Full control, server-side build, no local Docker needed | Slower (builds on every apply if changed) | Local development, custom builds |
| **Push via CI/CD** | Most flexible, separates build from infrastructure | Requires pipeline setup | Production deployments |

---

## Configuration Examples

### Example 1: Development with Local Dockerfile

```hcl
# app1-dev.tfvars
applicationname = "app1"
environment     = "development"

# Build custom UI from local Dockerfile
webui_dockerfile_path = "./webui-docker/Dockerfile"
webui_build_context   = "./webui-docker"
webui_image_tag       = "dev-latest"
webui_port            = 3000
```

### Example 2: Production with External Image

```hcl
# app1-prod.tfvars
applicationname = "app1"
environment     = "production"

# Import stable image from Docker Hub
webui_image     = "docker.io/mycompany/n8n-webui:2.1.0"
webui_image_tag = "2.1.0"
webui_port      = 3000

# Don't build from Dockerfile
webui_dockerfile_path = ""
```

### Example 3: CI/CD Pipeline Push

```hcl
# app1-prod.tfvars
applicationname = "app1"
environment     = "production"

# CI/CD will push the image
webui_image           = ""  # Don't import
webui_dockerfile_path = ""  # Don't build
webui_image_tag       = "v2.1.0-abc123"  # Tag pushed by CI/CD
webui_port            = 3000
```

---

## How the Module Decides What to Do

The container-registry module uses this logic:

```
IF webui_source_image != ""
  THEN import image from external registry
ELSE IF webui_dockerfile_path != ""
  THEN build image from Dockerfile
ELSE
  THEN expect image already in ACR (pushed by CI/CD)
```

**Priority**:
1. Import (if `webui_image` is set)
2. Build (if `webui_dockerfile_path` is set)
3. Use existing (if both are empty)

---

## Troubleshooting

### Error: Dockerfile Not Found

**Error**:
```
Error: local-exec provisioner error
Could not read Dockerfile at path: ./webui-docker/Dockerfile
```

**Solution**:
- Verify the path is correct relative to Terraform root
- Check file exists: `ls -la ./webui-docker/Dockerfile`
- Use absolute path if relative path doesn't work

### Error: Build Context Too Large

**Error**:
```
Error: Build context is too large (>1GB)
```

**Solution**:
- Add `.dockerignore` file to webui directory
- Exclude unnecessary files:
  ```
  node_modules/
  .git/
  *.log
  .terraform/
  ```

### Error: ACR Build Failed

**Error**:
```
Error running command 'az acr build ...'
Step X failed: ...
```

**Solution**:
- Check Dockerfile syntax
- Ensure all COPY/ADD paths exist in build context
- Test build locally first:
  ```bash
  docker build -f ./webui-docker/Dockerfile ./webui-docker
  ```

### Build Triggers Every Apply

**Issue**: ACR build runs on every `terraform apply` even without changes

**Why**: The `triggers` block includes Dockerfile path, so if path changes or tag changes, it rebuilds

**Solution**:
- Use consistent image tags
- Consider using CI/CD push method for production

---

## Best Practices

### 1. Development

Use Dockerfile build for fast iteration:
```hcl
webui_dockerfile_path = "./webui-docker/Dockerfile"
webui_image_tag       = "dev-${timestamp()}"  # Always rebuild
```

### 2. Staging

Import from a registry after manual verification:
```hcl
webui_image     = "docker.io/mycompany/n8n-webui:staging"
webui_image_tag = "staging-20260323"
```

### 3. Production

Use CI/CD push with immutable tags:
```hcl
webui_image           = ""  # CI/CD handles it
webui_dockerfile_path = ""
webui_image_tag       = "v2.1.0"  # Immutable version tag
```

### 4. Multi-Environment

Use different methods per environment:
```hcl
# dev.tfvars - build locally
webui_dockerfile_path = "./webui-docker/Dockerfile"

# prod.tfvars - CI/CD push
webui_dockerfile_path = ""
webui_image_tag       = var.webui_version  # From CI/CD
```

---

## Sample Dockerfile

Here's a sample Dockerfile for the custom web UI:

```dockerfile
# webui-docker/Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --production

COPY src/ ./src/
COPY public/ ./public/

FROM node:18-alpine

WORKDIR /app
COPY --from=builder /app /app

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

EXPOSE 3000
CMD ["node", "src/index.js"]
```

---

## Related Documentation

- [MODULE_STRUCTURE.md](MODULE_STRUCTURE.md) - Module architecture
- [QUICKSTART.md](QUICKSTART.md) - Deployment guide
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)

---

**Last Updated**: 2026-03-23
**Version**: 2.0
