data "azurerm_client_config" "CURRENT" {}

////////////////////////
// Virtual Network
////////////////////////

data "azurerm_virtual_network" "MAIN" {
  name                = var.virtual_network.name
  resource_group_name = var.virtual_network.resource_group_name
}

////////////////////////
// Resource Group (Compute)
////////////////////////

resource "azurerm_resource_group" "MAIN" {
  count = var.resource_group.create ? 1 : 0
  
  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = var.tags
}

data "azurerm_resource_group" "MAIN" {
  depends_on = [azurerm_resource_group.MAIN]
  
  name = var.resource_group.name
}

////////////////////////
// Subnet
////////////////////////

resource "azurerm_subnet" "MAIN" {
  count = var.subnet.create ? 1 : 0
  
  name  = var.subnet.name
  
  address_prefixes = [cidrsubnet(
    element(data.azurerm_virtual_network.MAIN.address_space, var.subnet.vnet_index),
    var.subnet.newbits,
    var.subnet.netnum,
  )]

  virtual_network_name = data.azurerm_virtual_network.MAIN.name
  resource_group_name  = data.azurerm_virtual_network.MAIN.resource_group_name
}

data "azurerm_subnet" "MAIN" {
  depends_on = [azurerm_subnet.MAIN]

  name                 = var.subnet.name
  virtual_network_name = data.azurerm_virtual_network.MAIN.name
  resource_group_name  = data.azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Azure Key Vault
////////////////////////

resource "azurerm_key_vault" "MAIN" {
  count = 0
  
  name     = join("-", [var.prefix, "kv"])
  sku_name = "standard"
  
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enabled_for_disk_encryption = true
  
  access_policy {
    tenant_id = data.azurerm_client_config.CURRENT.tenant_id
    object_id = data.azurerm_client_config.CURRENT.object_id
    secret_permissions = ["Get"]
  }

  tags                = var.tags
  tenant_id           = data.azurerm_client_config.CURRENT.tenant_id
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

////////////////////////
// Network Security
////////////////////////

resource "azurerm_network_security_group" "MAIN" {
  count = length(var.nsg_rules) > 0 ? 1 : 0

  name = join("-", [data.azurerm_subnet.MAIN.name, "nsg"])

  dynamic "security_rule" {
    for_each = var.nsg_rules
    
    content {
      name     = security_rule.value["name"]
      priority = security_rule.value["priority"]
      //TODO ..
    }
  }
  
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
  location            = data.azurerm_virtual_network.MAIN.location
}

resource "azurerm_subnet_network_security_group_association" "MAIN" {
  count = length(var.nsg_rules) > 0 ? 1 : 0

  network_security_group_id = one(azurerm_network_security_group.MAIN[*].id)
  subnet_id                 = data.azurerm_subnet.MAIN.id
}

////////////////////////
// Network Interfaces
////////////////////////

resource "azurerm_application_security_group" "MAIN" {
  name = join("-", [var.prefix, "asg"])

  tags = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface" "MAIN" {
  count = var.vm_count
  
  name = join("-", [var.prefix, count.index, "nic"])

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = data.azurerm_subnet.MAIN.id
  }

  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface_application_security_group_association" "MAIN" {
  for_each = {
    for nic in azurerm_network_interface.MAIN: nic.name => nic.id
  }

  network_interface_id          = each.value
  application_security_group_id = azurerm_application_security_group.MAIN.id
}

////////////////////////
// Virtual Machines | Windows
////////////////////////

resource "azurerm_windows_virtual_machine" "MAIN" {
  count = upper(var.vm_os_type) != "WINDOWS" ? 0 : var.vm_count

  name = join("-", [var.prefix, count.index])
  size = var.vm_size
  
  admin_username = "adminuser"
  admin_password = "P@$$w0rd1234!"
  
  network_interface_ids = [
    azurerm_network_interface.MAIN[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.source_image_windows.publisher
    offer     = var.source_image_windows.offer
    sku       = var.source_image_windows.sku
    version   = var.source_image_windows.version
  }

  tags                = var.tags
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// Virtual Machines | Linux
////////////////////////

resource "azurerm_linux_virtual_machine" "MAIN" {
  count = upper(var.vm_os_type) != "LINUX" ? 0 : var.vm_count

  name = join("-", [var.prefix, count.index])
  size = var.vm_size
  
  disable_password_authentication = false
  admin_username                  = "adminuser"
  admin_password                  = "P@$$w0rd1234!"
  
  network_interface_ids = [
    azurerm_network_interface.MAIN[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.source_image_linux.publisher
    offer     = var.source_image_linux.offer
    sku       = var.source_image_linux.sku
    version   = var.source_image_linux.version
  }

  tags                = var.tags
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}
