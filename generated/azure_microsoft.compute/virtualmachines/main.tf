# Existing RG + VNet
data "azurerm_resource_group" "target" {
  name = "Idea2.0"
}

data "azurerm_virtual_network" "vnet" {
  name                = "idea2.0Vnet"
  resource_group_name = data.azurerm_resource_group.target.name
}

# If VNet already has at least one subnet, use it.
# Otherwise, create a new subnet automatically and use that.
locals {
  use_existing_subnet = length(data.azurerm_virtual_network.vnet.subnets) > 0
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_network_interface" "nic" {
  name                = "myVMNic"
  location            = data.azurerm_resource_group.target.location
  resource_group_name = data.azurerm_resource_group.target.name

  ip_configuration {
    name                          = "myVMIPConfig"
    subnet_id                     = local.use_existing_subnet
      ? element(data.azurerm_virtual_network.vnet.subnets, 0)
      : azurerm_subnet.auto[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "myVM" {
  name                = "myVM"
  location            = data.azurerm_resource_group.target.location
  resource_group_name = data.azurerm_resource_group.target.name
  size                = "Standard_DS1_v2"
  admin_username      = "azureuser"
  admin_password      = "Password1234!"
  network_interface_ids = [azurerm_network_interface.nic.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    create_option       = "FromImage"
  }
}

resource "azurerm_subnet" "auto" {
  count = local.use_existing_subnet ? 0 : 1
  name  = "auto-${random_string.suffix.result}"

  resource_group_name  = data.azurerm_resource_group.target.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name

  # Derive a child prefix from the first VNet address_space.
  address_prefixes = [cidrsubnet(data.azurerm_virtual_network.vnet.address_space[0], 1, 0)]
}