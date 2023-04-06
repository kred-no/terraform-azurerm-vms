terraform {
  required_version = ">= 1.4.2"

  backend "local" {
    path = "./.state/basic-example.tfstate"
  }

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id // ARM_SUBSCRIPTION_ID
  tenant_id       = var.tenant_id       // ARM_TENANT_ID
}
