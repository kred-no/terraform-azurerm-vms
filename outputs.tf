output "application_security_group" {
  sensitive = false
  value     = azurerm_application_security_group.MAIN
}

output "virtual_machine" {
  sensitive = false

  value = try(
    azurerm_windows_virtual_machine.MAIN,
    azurerm_linux_virtual_machine.MAIN,
  )
}

output "network_interface" {
  sensitive = false
  value     = azurerm_network_interface.MAIN
}