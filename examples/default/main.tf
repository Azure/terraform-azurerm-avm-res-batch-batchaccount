terraform {
  required_version = ">= 1.11.4, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116.0, < 5.0.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  resource_providers_to_register = ["Microsoft.Batch"]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}


## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "0.8.2"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

module "avm_res_storage_storageaccount" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.7.4"

  enable_telemetry              = var.enable_telemetry
  name                          = module.naming.storage_account.name_unique
  parent_id                     = azurerm_resource_group.this.id
  location                      = azurerm_resource_group.this.location
  shared_access_key_enabled     = false
  public_network_access_enabled = false
  account_replication_type      = "ZRS"
  tags = {
    "environment" = "test"
  }
}

# This is the module call
# Do not specify location here due to the randomization above.
# Leaving location as `null` will cause the module to use the resource group location
# with a data source.
# Assuming the module is two levels up in the directory structure
module "azure_batch_account" {
  source = "../.."

  # Basic configuration
  name                                = module.naming.batch_account.name_unique
  resource_group_name                 = azurerm_resource_group.this.name
  location                            = azurerm_resource_group.this.location
  pool_allocation_mode                = "BatchService"
  public_network_access_enabled       = true
  storage_account_id                  = module.avm_res_storage_storageaccount.resource.id
  storage_account_authentication_mode = "BatchAccountManagedIdentity"

  # Add system identity to access the key
  identity = [
    {
      type = "SystemAssigned"
    }
  ]

  tags = {
    "environment" = "test"
  }
}