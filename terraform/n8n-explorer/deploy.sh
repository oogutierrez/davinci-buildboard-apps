#!/usr/bin/env bash
# ============================================================
#  n8n Workflow Explorer — Azure Container App Deployment
#  Deploys into the SAME environment as your n8n instance
# ============================================================

set -euo pipefail

# ── EDIT THESE ───────────────────────────────────────────────
RESOURCE_GROUP="your-resource-group"        # RG where n8n lives
ENVIRONMENT_NAME="your-container-app-env"   # Existing CAE name
ACR_NAME="yourregistry"                     # Azure Container Registry name
IMAGE_NAME="n8n-workflow-explorer"
IMAGE_TAG="latest"
APP_NAME="n8n-explorer"
# ─────────────────────────────────────────────────────────────

IMAGE_FULL="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

echo "▶ Logging in to ACR..."
az acr login --name "$ACR_NAME"

echo "▶ Building & pushing Docker image..."
docker build -t "$IMAGE_FULL" .
docker push "$IMAGE_FULL"

echo "▶ Checking if Container App already exists..."
if az containerapp show \
      --name "$APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --output none 2>/dev/null; then

  echo "▶ Updating existing Container App..."
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$IMAGE_FULL"

else

  echo "▶ Creating new Container App in existing environment..."

  # Get ACR credentials
  ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
  ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

  az containerapp create \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$IMAGE_FULL" \
    --registry-server "${ACR_NAME}.azurecr.io" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 80 \
    --ingress external \
    --cpu 0.25 \
    --memory 0.5Gi \
    --min-replicas 1 \
    --max-replicas 1

fi

echo ""
echo "✅ Deployment complete!"
echo "🌐 App URL:"
az containerapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn \
  --output tsv | sed 's/^/   https:\/\//'
