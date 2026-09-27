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