terraform {
  required_version = "~> 1.11.4"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.9"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.74.0, < 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}