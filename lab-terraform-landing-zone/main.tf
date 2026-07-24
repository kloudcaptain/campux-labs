terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
}

variable "location" { default = "eastus" }

resource "azurerm_resource_group" "lz" {
  name     = "campux-lab-lz-rg"
  location = var.location
  tags = {
    environment = "lab"
    owner       = "campux"
    managed_by  = "terraform"
  }
}

output "resource_group" {
  value = azurerm_resource_group.lz.name
}
