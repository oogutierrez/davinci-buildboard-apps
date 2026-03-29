# n8n Workflow Explorer — Azure Container App Deployment

Deploy the n8n Workflow Explorer as a Container App into the **same Azure Container App Environment** as your n8n instance.

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running locally)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- An existing **Azure Container Registry (ACR)**
- Your n8n **Container App Environment** name

---

## Project Structure

```
n8n-explorer/
├── index.html      ← The workflow explorer web app
├── Dockerfile      ← nginx:alpine image
├── nginx.conf      ← nginx server config
├── deploy.sh       ← One-shot deploy script
└── README.md
```

---

## Step-by-Step Deployment

### 1. Edit deploy.sh

Open `deploy.sh` and fill in the four variables at the top:

```bash
RESOURCE_GROUP="your-resource-group"       # RG where n8n lives
ENVIRONMENT_NAME="your-container-app-env"  # Existing env name
ACR_NAME="yourregistry"                    # ACR name (no .azurecr.io)
APP_NAME="n8n-explorer"                    # Name for the new app
```

To find your environment name:
```bash
az containerapp env list --resource-group <your-rg> --query "[].name" -o tsv
```

### 2. Log in to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Run the deploy script

```bash
chmod +x deploy.sh
./deploy.sh
```

This will:
1. Build the Docker image locally
2. Push it to your ACR
3. Create (or update) the Container App in your existing environment
4. Print the public URL when done

---

## Accessing Your n8n Instance from the Explorer

Since both apps share the same Container App Environment, you can use the **internal DNS name** of your n8n app instead of its public URL:

```
http://<n8n-app-name>
```

For example, if your n8n Container App is named `n8n`, enter:
```
http://n8n
```
in the **n8n Base URL** field of the explorer. Internal traffic stays within the environment and never leaves Azure.

---

## Manual Deployment (without the script)

```bash
# 1. Build & push image
az acr login --name <ACR_NAME>
docker build -t <ACR_NAME>.azurecr.io/n8n-explorer:latest .
docker push <ACR_NAME>.azurecr.io/n8n-explorer:latest

# 2. Create the Container App
az containerapp create \
  --name n8n-explorer \
  --resource-group <RESOURCE_GROUP> \
  --environment <ENVIRONMENT_NAME> \
  --image <ACR_NAME>.azurecr.io/n8n-explorer:latest \
  --registry-server <ACR_NAME>.azurecr.io \
  --registry-username $(az acr credential show --name <ACR_NAME> --query username -o tsv) \
  --registry-password $(az acr credential show --name <ACR_NAME> --query "passwords[0].value" -o tsv) \
  --target-port 80 \
  --ingress external \
  --cpu 0.25 \
  --memory 0.5Gi \
  --min-replicas 1 \
  --max-replicas 1
```

---

## CORS on n8n

If the explorer is on a different domain than n8n, add these env vars to your n8n Container App:

| Variable | Value |
|---|---|
| `N8N_CORS_ENABLED` | `true` |
| `N8N_CORS_ORIGIN` | `https://<explorer-fqdn>` |

Set them via Azure Portal → your n8n Container App → Environment Variables, or via CLI:

```bash
az containerapp update \
  --name <n8n-app-name> \
  --resource-group <RESOURCE_GROUP> \
  --set-env-vars N8N_CORS_ENABLED=true N8N_CORS_ORIGIN="https://<explorer-fqdn>"
```
