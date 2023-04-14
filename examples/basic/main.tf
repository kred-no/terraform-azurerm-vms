////////////////////////
// Configuration
////////////////////////

locals {
  rg_prefix   = "tf-vms"
  rg_location = "northeurope"

  vnet_name          = "x-virtual-network"
  vnet_address_space = ["192.168.168.0/24"]
}

////////////////////////
// Resources
////////////////////////

resource "random_id" "X" {
  keepers = {
    prefix = local.rg_prefix
  }

  byte_length = 3
}

resource "azurerm_resource_group" "MAIN" {
  name     = join("-", [random_id.X.keepers.prefix, "VNet", random_id.X.hex])
  location = local.rg_location
}

resource "azurerm_virtual_network" "MAIN" {
  name          = local.vnet_name
  address_space = local.vnet_address_space
  
  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

////////////////////////
// Module | Linux
////////////////////////

module "LINUX_VM" {
  source = "../../../terraform-azurerm-vms"
  
  // Overrides
  vm_os_type = "Linux"
  
  subnet = {
    name = "LinuxVMs"
  }

  // External Resource References
  resource_group  = azurerm_resource_group.MAIN
  virtual_network = azurerm_virtual_network.MAIN
}

////////////////////////
// Module | Windows
////////////////////////

module "WINDOWS_VM" {
  source = "../../../terraform-azurerm-vms"
  
  // Overrides
  vm_os_type = "Windows"
  
  subnet = {
    name = "WindowsVMs"
  }

  // External Resource References
  resource_group  = azurerm_resource_group.MAIN
  virtual_network = azurerm_virtual_network.MAIN
}
