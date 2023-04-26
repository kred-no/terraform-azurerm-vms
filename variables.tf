////////////////////////
// Resources
////////////////////////

variable "tags" {
  type    = map(string)
  default = {}
}

////////////////////////
// Subnet
////////////////////////

variable "resource_group" {
  type = object({
    name     = string
    location = string
  })
}

variable "subnet" {
  type = object({
    name                 = string
    resource_group_name  = string
    virtual_network_name = string
  })
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

variable "vm_prefix" {
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

variable "source_image_id" {
  type    = string
  default = null
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

variable "admin_username" {
  type    = string
  default = "AdminUser"
}

variable "admin_password" {
  type    = string
  default = "P@$$w0rdL3ss!"
}

variable "admin_ssh_keys" {
  description = "Linux Only."
  type        = list(string)

  default = []
}