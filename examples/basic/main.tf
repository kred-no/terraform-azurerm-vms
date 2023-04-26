////////////////////////
// Configuration
////////////////////////

locals {
  prefix   = "tfvms"
  location = "northeurope"

  vnet_name   = "DemoVirtualNetwork"
  subnet_name = "ExampleVmSubnet"

  vnet_address_space      = [cidrsubnet("192.168.168.0/24", 0, 0)]
  subnet_address_prefixes = [cidrsubnet("192.168.168.0/24", 2, 0)]
}

////////////////////////
// Resources
////////////////////////

resource "random_string" "RESOURCE_GROUP" {
  length  = 5
  special = false

  keepers = {
    prefix = local.prefix
  }
}

resource "azurerm_resource_group" "MAIN" {
  name     = format("%s-%s", random_string.RESOURCE_GROUP.keepers.prefix, random_string.RESOURCE_GROUP.result)
  location = local.location
}

resource "azurerm_virtual_network" "MAIN" {
  name          = local.vnet_name
  address_space = local.vnet_address_space

  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

resource "azurerm_subnet" "MAIN" {
  name             = local.subnet_name
  address_prefixes = local.subnet_address_prefixes

  virtual_network_name = azurerm_virtual_network.MAIN.name
  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Module | Linux
////////////////////////

module "LINUX_VM" {
  source = "../../../terraform-azurerm-vms"

  depends_on = [
    azurerm_resource_group.MAIN,
    azurerm_subnet.MAIN,
  ]

  // Overrides
  vm_prefix  = "lnx"
  vm_os_type = "Linux"

  // External Resource References
  subnet         = azurerm_subnet.MAIN
  resource_group = azurerm_resource_group.MAIN
}

output "LINUX_appid" {
  sensitive = false
  value     = one(module.LINUX_VM[*].application_security_group.id)
}

output "LINUX_nic" {
  sensitive = false
  value     = one(module.LINUX_VM[*].network_interface.0.name)
}

////////////////////////
// Module | Windows
////////////////////////

module "WINDOWS_VM" {
  source = "../../../terraform-azurerm-vms"

  // Overrides
  vm_prefix  = "win"
  vm_os_type = "Windows"


  // External Resource References
  subnet         = azurerm_subnet.MAIN
  resource_group = azurerm_resource_group.MAIN
}

output "WINDOWS_appid" {
  sensitive = false
  value     = one(module.WINDOWS_VM[*].application_security_group.id)
}

output "WINDOWS_nic" {
  sensitive = false
  value     = one(module.WINDOWS_VM[*].network_interface.0.name)
}
