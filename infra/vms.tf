resource "azurerm_subnet" "office" {
  name                 = "office-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]

  # No public IPs on these VMs; they need outbound access only to apt-install at boot.
  default_outbound_access_enabled = true
}

resource "azurerm_network_security_group" "office" {
  name                = "${var.project}-office-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Only the AKS subnet (where Prometheus runs) may reach node_exporter.
resource "azurerm_network_security_rule" "allow_scrape" {
  name                        = "allow-node-exporter-from-aks"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9100"
  source_address_prefix       = azurerm_subnet.aks.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.office.name
}

# Azure's default rules allow all VNet-to-VNet traffic; close that.
resource "azurerm_network_security_rule" "deny_vnet" {
  name                        = "deny-other-vnet-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.office.name
}

resource "azurerm_subnet_network_security_group_association" "office" {
  subnet_id                 = azurerm_subnet.office.id
  network_security_group_id = azurerm_network_security_group.office.id
}

resource "azurerm_network_interface" "office" {
  count               = var.office_vm_count
  name                = "${var.project}-office-${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.office.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.office.address_prefixes[0], 10 + count.index)
  }
}

resource "azurerm_linux_virtual_machine" "office" {
  count                           = var.office_vm_count
  name                            = "${var.project}-office-${count.index + 1}"
  computer_name                   = "office-pc-${count.index + 1}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.office_vm_size
  admin_username                  = "netmon"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.office[count.index].id]
  custom_data                     = filebase64("${path.module}/cloud-init.yaml")

  admin_ssh_key {
    username   = "netmon"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
