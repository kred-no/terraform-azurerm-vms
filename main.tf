////////////////////////
// Sources
////////////////////////

data "azurerm_client_config" "CURRENT" {}

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

data "azurerm_virtual_network" "MAIN" {
  name                = var.subnet.virtual_network_name
  resource_group_name = var.subnet.resource_group_name
}

data "azurerm_subnet" "MAIN" {
  name                 = var.subnet.name
  virtual_network_name = var.subnet.virtual_network_name
  resource_group_name  = var.subnet.resource_group_name
}

////////////////////////
// Network Interfaces
////////////////////////

resource "azurerm_application_security_group" "MAIN" {
  name = format("%s-asg", var.vm_prefix)

  tags                = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface" "MAIN" {
  count = var.vm_count

  depends_on = [ // Create after ASG
    azurerm_application_security_group.MAIN,
  ]

  name = format("%s%s-nic", var.vm_prefix, count.index)

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
    for nic in azurerm_network_interface.MAIN : nic.name => nic.id
  }

  network_interface_id          = each.value
  application_security_group_id = azurerm_application_security_group.MAIN.id
}

////////////////////////
// Virtual Machines | Windows
////////////////////////

resource "azurerm_windows_virtual_machine" "MAIN" {
  count = upper(var.vm_os_type) != "WINDOWS" ? 0 : var.vm_count

  name = format("%s%s", var.vm_prefix, count.index)
  size = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

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

  dynamic "source_image_reference" {
    for_each = var.source_image_id != null ? [] : var.source_image_windows[*]

    content {
      publisher = source_image_reference.value["publisher"]
      offer     = source_image_reference.value["offer"]
      sku       = source_image_reference.value["sku"]
      version   = source_image_reference.value["version"]
    }
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

  name = format("%s%s", var.vm_prefix, count.index)
  size = var.vm_size

  disable_password_authentication = length(var.admin_password) > 0 ? false : true
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password

  dynamic "admin_ssh_key" {
    for_each = var.admin_ssh_keys

    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

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

  source_image_id = var.source_image_id

  dynamic "source_image_reference" {
    for_each = var.source_image_id != null ? [] : var.source_image_linux[*]

    content {
      publisher = source_image_reference.value["publisher"]
      offer     = source_image_reference.value["offer"]
      sku       = source_image_reference.value["sku"]
      version   = source_image_reference.value["version"]
    }
  }

  tags                = var.tags
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}
