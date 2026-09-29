variable "project" {
  description = "Short name used for all resource names"
  type        = string
  default     = "netmon"
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "eastasia"

}

variable "unique_suffix" {
  description = "Short unique string (lowercase letters/digits) to make ACR and DB names globally unique"
  type        = string
}

variable "pg_admin_user" {
  type    = string
  default = "netmonadmin"
}

variable "pg_admin_password" {
  type      = string
  sensitive = true
}