resource "azurerm_resource_group" "main" {
  name     = "${var.project}-rg"
  location = var.location
}