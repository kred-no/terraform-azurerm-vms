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

  source_image_id = var.source_image_id

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

////////////////////////
// VM Extension | BG Info
////////////////////////

resource "azurerm_virtual_machine_extension" "BGINFO" {
  count = alltrue([
    upper(var.vm_os_type) != "LINUX",
    var.vm_bginfo.enabled,
  ]) ? var.vm_count : 0

  name      = "BGInfo"
  publisher = "Microsoft.Compute"
  type      = "BGInfo"

  type_handler_version       = var.vm_bginfo.type_handler_version
  auto_upgrade_minor_version = var.vm_bginfo.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.vm_bginfo.automatic_upgrade_enabled

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN[count.index].id

  lifecycle {
    ignore_changes = []
  }
}

////////////////////////
// VM Extension | AAD Login
////////////////////////

resource "azurerm_virtual_machine_extension" "AADLOGIN_WINDOWS" {
  count = alltrue([
    upper(var.vm_os_type) != "LINUX",
    var.vm_aadlogin.enabled
  ]) ? var.vm_count : 0

  name      = "AADLogin"
  publisher = "Microsoft.Azure.ActiveDirectory"
  type      = "AADLoginForWindows"

  type_handler_version       = var.vm_aadlogin.type_handler_version
  auto_upgrade_minor_version = var.vm_aadlogin.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.vm_aadlogin.automatic_upgrade_enabled

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN[count.index].id

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

resource "azurerm_virtual_machine_extension" "AADLOGIN_LINUX" {
  count = alltrue([
    upper(var.vm_os_type) != "WINDOWS",
    var.vm_aadlogin.enabled
  ]) ? var.vm_count : 0

  name      = "AADLogin"
  publisher = "Microsoft.Azure.ActiveDirectory"
  type      = "AADLoginForLinux"

  type_handler_version       = var.vm_aadlogin.type_handler_version
  auto_upgrade_minor_version = var.vm_aadlogin.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.vm_aadlogin.automatic_upgrade_enabled

  tags               = var.tags
  virtual_machine_id = azurerm_linux_virtual_machine.MAIN[count.index].id

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

////////////////////////
// Test | Shutdown Schedule
////////////////////////

/*variable "vm_shutdown_schedule" {
  type = object({
    enabled               = optional(bool, true)
    timezone              = optional(string, "W. Europe Standard Time")
    daily_recurrence_time = optional(string, "1800")
    
    notification_settings = optional(object({
      enabled         = optional(bool, false)
      email           = optional(string)
      time_in_minutes = optional(number)
      webhook_url     = optional(string)
    }), {})
  })
  
  default = null
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "MAIN" {
  for_each = {
    for vm in azurerm_linux_virtual_machine.MAIN: vm.name => vm
    if var.vm_shutdown_schedule.enabled
  }
  
  enabled               = var.vm_shutdown_schedule.enabled
  daily_recurrence_time = "1700"
  timezone              = "Pacific Standard Time"

  notification_settings {
    enabled         = true
    time_in_minutes = "60"
    webhook_url     = "https://sample-webhook-url.example.com"
  }
  
  tags = var.tags
  virtual_machine_id = azurerm_linux_virtual_machine.MAIN[each.key].id
  location           = data.azurerm_resource_group.MAIN.location
}*/

////////////////////////
// Test | Automation Tasks
////////////////////////

resource "azurerm_automation_account" "MAIN" {
  count = length(var.automation_account_sku) > 0 ? 1 : 0

  name     = format("%s%s", var.vm_prefix, "automation-account")
  sku_name = var.automation_account_sku

  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

resource "azurerm_automation_schedule" "MAIN" {
  for_each = {
    for schedule in var.automation_schedules : schedule.name => schedule
  }

  name        = each.key
  description = each.value["description"]
  frequency   = each.value["frequency"]
  interval    = each.value["interval"]
  timezone    = each.value["timezone"]
  start_time  = each.value["start_time"]
  expiry_time = each.value["expiry_time"]
  week_days   = each.value["week_days"]
  month_days  = each.value["month_days"]

  dynamic "monthly_occurrence" {
    for_each = each.value["monthly_occurrence"]

    content {
      day        = monthly_occurrence.value["day"]
      occurrence = monthly_occurrence.value["occurrence"]
    }
  }

  automation_account_name = one(azurerm_automation_account.MAIN[*].name)
  resource_group_name     = data.azurerm_resource_group.MAIN.name
}

resource "azurerm_automation_runbook" "MAIN" {
  for_each = {
    for runbook in var.automation_runbooks : runbook.name => runbook
  }

  name         = each.key
  description  = each.value["description"]
  log_verbose  = each.value["log_verbose"]
  log_progress = each.value["log_progress"]
  runbook_type = each.value["runbook_type"]
  content      = each.value["content"]

  dynamic "publish_content_link" {
    for_each = each.value["publish_content_link"]

    content {
      uri     = publish_content_link.value["uri"]
      version = publish_content_link.value["version"]

      dynamic "hash" {
        for_each = publish_content_link.value["hash"][*]

        content {
          algorithm = hash.value["algorithm"]
          value     = hash.value["value"]
        }
      }
    }
  }

  automation_account_name = one(azurerm_automation_account.MAIN[*].name)
  location                = data.azurerm_resource_group.MAIN.location
  resource_group_name     = data.azurerm_resource_group.MAIN.name
}


resource "azurerm_automation_job_schedule" "MAIN" {
  for_each = {
    for job in var.automation_job_schedules : format("%s-%s", job.runbook_name, job.schedule_name) => job
  }

  runbook_name = each.value["runbook_name"]
  parameters   = each.value["parameters"]
  run_on       = each.value["run_on"]

  schedule_name           = azurerm_automation_schedule.MAIN[each.value["schedule_name"]].name
  automation_account_name = one(azurerm_automation_account.MAIN[*].name)
  resource_group_name     = data.azurerm_resource_group.MAIN.name
}
