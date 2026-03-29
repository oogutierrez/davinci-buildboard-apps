variable "server_name" {
  description = "Name of the PostgreSQL flexible server"
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

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "admin_username" {
  description = "Administrator username"
  type        = string
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 32768
}

variable "sku_name" {
  description = "SKU name for the server"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "delegated_subnet_id" {
  description = "Subnet ID delegated for PostgreSQL"
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for PostgreSQL"
  type        = string
}

variable "zone" {
  description = "Availability zone"
  type        = string
  default     = "1"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "database_charset" {
  description = "Database charset"
  type        = string
  default     = "UTF8"
}

variable "database_collation" {
  description = "Database collation"
  type        = string
  default     = "en_US.utf8"
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the managed identity for Reader role"
  type        = string
}

variable "prevent_destroy" {
  description = "Whether to prevent destruction of the server"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
