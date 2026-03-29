variable "registry_name" {
  description = "Name of the container registry"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "sku" {
  description = "SKU for the container registry"
  type        = string
  default     = "Premium"
}

variable "private_endpoint_name" {
  description = "Name of the private endpoint for ACR"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for the private endpoint"
  type        = string
}

variable "acr_private_dns_zone_id" {
  description = "Private DNS zone ID for ACR"
  type        = string
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the managed identity for ACR pull access"
  type        = string
}

variable "n8n_image_tag" {
  description = "Tag for n8n images to import"
  type        = string
  default     = "latest"
}

variable "webui_source_image" {
  description = "Source image for web UI to import (leave empty if pushing directly to ACR)"
  type        = string
  default     = ""
}

variable "webui_image_tag" {
  description = "Tag for web UI image"
  type        = string
  default     = "latest"
}

variable "webui_dockerfile_path" {
  description = "Path to Dockerfile for building custom web UI (relative to Terraform root or absolute path)"
  type        = string
  default     = ""
}

variable "webui_build_context" {
  description = "Build context directory for web UI Docker build (default is same directory as Dockerfile)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
