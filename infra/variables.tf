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
variable "office_vm_count" {
  description = "Number of simulated office machines"
  type        = number
  default     = 2
}

variable "office_vm_size" {
  type    = string
  default = "Standard_B2ts_v2"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
