#!/bin/bash

# Azure Container App Deployment Script
# This script automates the deployment of the n8n Custom UI to Azure Container Apps

set -e

# Configuration - Update these values
SUBSCRIPTION_ID="3383346e-81ea-4a09-bdeb-566a81f7f484"
RESOURCE_GROUP="rg-app1-n8n-dev"
LOCATION="eastus2"
ENVIRONMENT_NAME="cae-app1-n8n-dev"
APPLICATION_NAME="app1"
CONTAINER_APP_NAME="$APPLICATION_NAME-n8n-custom-ui"
ACR_NAME="acrapp1n8ndev"
IMAGE_NAME="n8n-custom-ui"
IMAGE_TAG="latest"
MANAGED_IDENTITY_NAME="mi-app1-n8n-dev"

# Environment variables - Set these before running
N8N_API_URL="${N8N_API_URL:-https://your-n8n-instance.com}"
N8N_API_KEY="${N8N_API_KEY}"
JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 32)}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Azure Container App Deployment ===${NC}"

# Check if required environment variables are set
if [ -z "$N8N_API_KEY" ]; then
    echo -e "${RED}Error: N8N_API_KEY environment variable is not set${NC}"
    exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: ADMIN_PASSWORD environment variable is not set${NC}"
    exit 1
fi

# Login to Azure
echo -e "${GREEN}Step 1: Logging in to Azure...${NC}"
az login

# Set the subscription
echo -e "${GREEN}Step 2: Setting subscription...${NC}"
az account set --subscription "$SUBSCRIPTION_ID"

# Get the ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv | tr -d '\r')

# Build and push Docker image
# echo -e "${GREEN}Step 6: Building and pushing Docker image...${NC}"
# az acr build \
#   --registry "$ACR_NAME" \
#   --image "$IMAGE_NAME:$IMAGE_TAG" \
#   --file Dockerfile \
#  .

# Get identity details
IDENTITY_RESOURCE_ID=$(az identity show \
  --name "$MANAGED_IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id --output tsv | tr -d '\r')


# Validate identity retrieval
if [ -z "$IDENTITY_RESOURCE_ID" ]; then
    echo -e "${RED}Error: Could not retrieve managed identity '$MANAGED_IDENTITY_NAME' in resource group '$RESOURCE_GROUP'${NC}"
    echo -e "${RED}Verify the identity exists: az identity show --name $MANAGED_IDENTITY_NAME --resource-group $RESOURCE_GROUP${NC}"
    exit 1
fi

echo -e "${GREEN}Identity Resource ID: $IDENTITY_RESOURCE_ID${NC}"

# Deploy Container App
echo -e "${GREEN}Step 8: Deploying Container App...${NC}"
MSYS_NO_PATHCONV=1 az containerapp create \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-identity "$IDENTITY_RESOURCE_ID" \
  --user-assigned "$IDENTITY_RESOURCE_ID" \
  --target-port 3000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 10 \
  --cpu 0.5 \
  --memory 1Gi \
  --env-vars \
    NODE_ENV=production \
    PORT=3000 \
    N8N_API_URL="$N8N_API_URL" \
    N8N_API_KEY=secretref:n8n-api-key \
    JWT_SECRET=secretref:jwt-secret \
    ADMIN_USERNAME="$ADMIN_USERNAME" \
    ADMIN_PASSWORD=secretref:admin-password \
  --secrets \
    n8n-api-key="$N8N_API_KEY" \
    jwt-secret="$JWT_SECRET" \
    admin-password="$ADMIN_PASSWORD"

# Get the app URL
echo -e "${GREEN}Step 9: Getting application URL...${NC}"
APP_URL=$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

echo -e "${BLUE}=== Deployment Complete ===${NC}"
echo -e "${GREEN}Your n8n Custom UI is available at: https://$APP_URL${NC}"
echo -e "${GREEN}Admin Username: $ADMIN_USERNAME${NC}"
echo -e "${GREEN}Admin Password: [SET BY YOU]${NC}"
