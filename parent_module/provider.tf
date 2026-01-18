terraform {
  required_providers {
    template = {
      source  = "hashicorp/template"
      version = "~> 2"
    }
  }
}
provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = "47f00bc6-c0a2-4ef3-8447-b76762fcc0ce"
}
