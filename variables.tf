////////////////////////
// Core Resources
////////////////////////

variable "resource_group" {
  type = object({
    create   = optional(bool, false)
    name     = string
    location = string
  })
}

variable "virtual_network" {
  type = object({
    name                = string
    resource_group_name = string
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}

////////////////////////
// Subnet
////////////////////////

variable "subnet" {
  type = object({
    create     = optional(bool, true)
    name       = optional(string, "VirtualMachines")
    vnet_index = optional(number, 0)
    newbits    = optional(number, 8)
    netnum     = optional(number, 0)
  })
  
  default = {}
}

////////////////////////
// Security
////////////////////////

variable "nsg_rules" {
  description = "Create Network Security Group if there is at least 1 rule defined."
  
  type = list(object({
    name     = string
    priority = number
    // TODO ..
  }))
  
  default = []
}

////////////////////////
// Virtual Machine
////////////////////////

variable "prefix" {
  type    = string
  default = "vm"
}

variable "vm_count" {
  type    = number
  default = 1
}

variable "vm_size" {
  type    = string
  default = "Standard_F2"
}

variable "vm_os_type" {
  type    = string
  default = "Windows"
  
  validation {
    condition     = contains(["Windows", "Linux"], var.vm_os_type)
    error_message = "Supported: 'Linux', 'Windows'"
  }
}

variable "source_image_windows" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })

  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

variable "source_image_linux" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })

  default = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}