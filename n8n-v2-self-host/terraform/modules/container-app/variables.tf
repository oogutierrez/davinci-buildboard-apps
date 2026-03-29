variable "app_name" {
  description = "Name of the container app"
  type        = string
}

variable "container_app_environment_id" {
  description = "ID of the Container App Environment"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "revision_mode" {
  description = "Revision mode (Single or Multiple)"
  type        = string
  default     = "Single"
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 1
}

variable "container_name" {
  description = "Name of the container"
  type        = string
}

variable "container_image" {
  description = "Container image reference"
  type        = string
}

variable "cpu" {
  description = "CPU allocation"
  type        = number
  default     = 0.5
}

variable "memory" {
  description = "Memory allocation (e.g., '1Gi')"
  type        = string
  default     = "1Gi"
}

variable "environment_variables" {
  description = "List of environment variables"
  type = list(object({
    name        = string
    value       = optional(string)
    secret_name = optional(string)
  }))
  default = []
}

variable "liveness_probe" {
  description = "Liveness probe configuration"
  type = object({
    transport               = string
    path                    = optional(string)
    port                    = number
    initial_delay           = optional(number)
    period_seconds          = optional(number)
    failure_count_threshold = optional(number)
  })
  default = null
}

variable "readiness_probe" {
  description = "Readiness probe configuration"
  type = object({
    transport               = string
    path                    = optional(string)
    port                    = number
    period_seconds          = optional(number)
    failure_count_threshold = optional(number)
  })
  default = null
}

variable "ingress" {
  description = "Ingress configuration"
  type = object({
    external_enabled = bool
    target_port      = number
    transport        = optional(string)
  })
  default = null
}

variable "registry_server" {
  description = "Container registry server"
  type        = string
}

variable "registry_identity_id" {
  description = "Managed identity ID for registry access"
  type        = string
}

variable "secrets" {
  description = "List of secrets"
  type = list(object({
    name  = string
    value = string
  }))
  default   = []
  sensitive = true
}

variable "identity_id" {
  description = "User-assigned managed identity ID"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
