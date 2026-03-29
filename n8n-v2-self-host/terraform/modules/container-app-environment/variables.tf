variable "environment_name" {
  description = "Name of the Container App Environment"
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

variable "infrastructure_subnet_id" {
  description = "Subnet ID for Container App Environment infrastructure (must be delegated to Microsoft.App/environments)"
  type        = string
}

variable "internal_load_balancer_enabled" {
  description = "Enable internal load balancer for VNet integration"
  type        = bool
  default     = true
}

variable "virtual_network_id" {
  description = "Virtual network ID to link the DNS zone"
  type        = string
}

variable "create_private_endpoint" {
  description = "Whether to create a private endpoint for the environment"
  type        = bool
  default     = true
}

variable "private_endpoint_name" {
  description = "Name of the private endpoint"
  type        = string
  default     = ""
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for the private endpoint"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for Container App Environment logs"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
