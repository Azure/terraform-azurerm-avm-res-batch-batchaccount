mock_provider "azurerm" {
  mock_resource "azurerm_batch_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Batch/batchAccounts/batchtest"
    }
  }
  mock_resource "azurerm_private_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/privateEndpoints/endpoint-test"
    }
  }
}

mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        }]
      }
    }
  }
}

mock_provider "modtm" {
  mock_data "modtm_module_source" {
    defaults = {
      module_source  = "registry.terraform.io/Azure/avm-res-batch-batchaccount/azurerm"
      module_version = "0.1.0"
    }
  }
}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "22222222-2222-2222-2222-222222222222"
    }
  }
}

variables {
  enable_telemetry    = false
  location            = "eastus"
  name                = "batchtest"
  resource_group_name = "batch-test"
  storage_account_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Storage/storageAccounts/batchstorage"
  tags = {
    environment = "test"
  }
}

run "no_private_endpoints" {
  command = apply

  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(output.resource_private_endpoints) == 0
    )
    error_message = "An empty interface must not create endpoints, locks or roles."
  }
}

run "telemetry_uses_mocked_providers" {
  command = apply
  variables {
    enable_telemetry = true
  }
  assert {
    condition     = length(modtm_telemetry.telemetry) == 1
    error_message = "Enabled telemetry must remain testable without collector access."
  }
}

run "managed_defaults" {
  command = apply

  variables {
    private_endpoints = {
      account = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        ip_configurations = {
          address = {
            name               = "account-ip"
            private_ip_address = "10.0.0.4"
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 1 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0
    )
    error_message = "Managed DNS must create exactly one endpoint."
  }
  assert {
    condition = (
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].name == "pe-batchtest" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].location == "eastus" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].resource_group_name == "batch-test" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].tags == var.tags &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].private_service_connection[0].name == "pse-batchtest" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].private_service_connection[0].subresource_names == tolist(["batchAccount"])
    )
    error_message = "Endpoint defaults must preserve existing names and use the Batch account service."
  }
  assert {
    condition = (
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].ip_configuration[0].subresource_name == "batchAccount" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].ip_configuration[0].member_name == "batchAccount" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["account"].ip_configuration[0].private_ip_address == "10.0.0.4"
    )
    error_message = "Static IP defaults must use the selected Batch service, not sites."
  }
  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups["account"].private_dns_zone_group) == 0 &&
      output.resource_private_endpoints["account"].id == azurerm_private_endpoint.this_managed_dns_zone_groups["account"].id
    )
    error_message = "Omitted DNS zones must stay absent and the endpoint output must retain the caller key."
  }
}

run "managed_overrides_locks_and_roles" {
  command = apply

  variables {
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 5
      max_interval_seconds = 30
    }
    timeouts = {
      create = "20m"
      read   = "3m"
      update = "15m"
      delete = "10m"
    }
    private_endpoints = {
      node = {
        name                            = "node-endpoint"
        location                        = "westus2"
        resource_group_name             = "endpoint-group"
        subnet_resource_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        subresource_name                = "nodeManagement"
        private_service_connection_name = "node-connection"
        network_interface_name          = "node-nic"
        private_dns_zone_group_name     = "batch-dns"
        private_dns_zone_resource_ids   = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/privateDnsZones/privatelink.batch.azure.com"]
        tags = {
          endpoint = "node"
        }
        ip_configurations = {
          address = {
            name               = "node-ip"
            private_ip_address = "10.0.0.5"
            member_name        = "custom-member"
          }
        }
        application_security_group_associations = {
          application = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/applicationSecurityGroups/test"
        }
        lock = {
          kind  = "ReadOnly"
          name  = "endpoint-lock"
          notes = "Endpoint lock notes."
        }
        role_assignments = {
          by_id = {
            name                                   = "11111111-1111-1111-1111-111111111111"
            role_definition_id_or_name             = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            principal_id                           = "00000000-0000-0000-0000-000000000001"
            principal_type                         = "ServicePrincipal"
            skip_service_principal_aad_check       = true
            description                            = "Endpoint access."
            condition                              = "@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEquals 'example'"
            condition_version                      = "2.0"
            delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
          }
          by_name = {
            role_definition_id_or_name       = "Reader"
            principal_id                     = "00000000-0000-0000-0000-000000000002"
            skip_service_principal_aad_check = true
          }
        }
      }
    }
  }

  assert {
    condition = (
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].name == "node-endpoint" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].location == "westus2" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].resource_group_name == "endpoint-group" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].custom_network_interface_name == "node-nic" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].tags == tomap({ endpoint = "node" }) &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].private_service_connection[0].name == "node-connection" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].private_service_connection[0].subresource_names == tolist(["nodeManagement"]) &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].ip_configuration[0].member_name == "custom-member" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].ip_configuration[0].subresource_name == "nodeManagement"
    )
    error_message = "Managed endpoint overrides and selected IP member must be forwarded unchanged."
  }
  assert {
    condition = (
      azurerm_private_endpoint.this_managed_dns_zone_groups["node"].private_dns_zone_group[0].name == "batch-dns" &&
      toset(azurerm_private_endpoint.this_managed_dns_zone_groups["node"].private_dns_zone_group[0].private_dns_zone_ids) == var.private_endpoints["node"].private_dns_zone_resource_ids &&
      azurerm_private_endpoint_application_security_group_association.this["node-application"].private_endpoint_id == azurerm_private_endpoint.this_managed_dns_zone_groups["node"].id
    )
    error_message = "DNS and application security group associations must use the managed endpoint."
  }
  assert {
    condition = (
      azapi_resource.private_endpoint_locks["node"].parent_id == azurerm_private_endpoint.this_managed_dns_zone_groups["node"].id &&
      azapi_resource.private_endpoint_locks["node"].name == "endpoint-lock" &&
      azapi_resource.private_endpoint_locks["node"].body.properties.level == "ReadOnly" &&
      azapi_resource.private_endpoint_locks["node"].body.properties.notes == "Endpoint lock notes."
    )
    error_message = "Endpoint lock names, kind and notes must be implemented, not discarded by the utility schema."
  }
  assert {
    condition = (
      length(azapi_resource.private_endpoint_role_assignments) == 2 &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].name == "11111111-1111-1111-1111-111111111111" &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].parent_id == azurerm_private_endpoint.this_managed_dns_zone_groups["node"].id &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].body.properties.principalId == "00000000-0000-0000-0000-000000000001" &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].body.properties.description == "Endpoint access." &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].body.properties.conditionVersion == "2.0" &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].body.properties.condition == var.private_endpoints["node"].role_assignments["by_id"].condition &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].body.properties.delegatedManagedIdentityResourceId == var.private_endpoints["node"].role_assignments["by_id"].delegated_managed_identity_resource_id
    )
    error_message = "Endpoint permissions must preserve explicit names, scope and all supported role settings."
  }
  assert {
    condition = (
      azapi_resource.private_endpoint_role_assignments["node-by_name"].name == "22222222-2222-2222-2222-222222222222" &&
      azapi_resource.private_endpoint_role_assignments["node-by_name"].body.properties.roleDefinitionId == var.private_endpoints["node"].role_assignments["by_id"].role_definition_id_or_name &&
      azapi_resource.private_endpoint_role_assignments["node-by_name"].body.properties.principalType == "ServicePrincipal"
    )
    error_message = "Role names must resolve and omitted assignment names must receive a UUID; skipping directory checks must retain the ServicePrincipal type."
  }
  assert {
    condition = (
      azapi_resource.private_endpoint_locks["node"].retry.interval_seconds == 5 &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].retry.max_interval_seconds == 30 &&
      azapi_resource.private_endpoint_locks["node"].timeouts.delete == "10m" &&
      azapi_resource.private_endpoint_role_assignments["node-by_id"].timeouts.create == "20m"
    )
    error_message = "Retry and timeouts must reach both AzAPI extension resources."
  }
}

run "unmanaged_dns_endpoint" {
  command = apply

  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      node = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        subresource_name              = "nodeManagement"
        private_dns_zone_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/privateDnsZones/privatelink.batch.azure.com"]
        tags                          = {}
        ip_configurations = {
          address = {
            name               = "node-ip"
            private_ip_address = "10.0.0.6"
          }
        }
        lock = {
          kind = "CanNotDelete"
        }
        role_assignments = {
          reader = {
            role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            principal_id               = "00000000-0000-0000-0000-000000000003"
            principal_type             = "Group"
          }
        }
        application_security_group_associations = {
          application = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/applicationSecurityGroups/test"
        }
      }
    }
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 1 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].private_dns_zone_group) == 0
    )
    error_message = "External DNS ownership must not create a duplicate endpoint or a managed zone group."
  }
  assert {
    condition = (
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].private_service_connection[0].subresource_names == tolist(["nodeManagement"]) &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].ip_configuration[0].member_name == "nodeManagement" &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].tags) == 0 &&
      output.resource_private_endpoints["node"].id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].id
    )
    error_message = "Unmanaged endpoints must honor service/IP settings, explicit empty tags and output keys."
  }
  assert {
    condition = (
      azapi_resource.private_endpoint_locks["node"].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].id &&
      azapi_resource.private_endpoint_locks["node"].name == "lock-CanNotDelete" &&
      azapi_resource.private_endpoint_role_assignments["node-reader"].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].id &&
      azapi_resource.private_endpoint_role_assignments["node-reader"].body.properties.principalType == "Group" &&
      azurerm_private_endpoint_application_security_group_association.this["node-application"].private_endpoint_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["node"].id
    )
    error_message = "Locks, roles and application security groups must attach to the selected unmanaged endpoint."
  }
}

run "inherit_lock_and_opt_out" {
  command = apply

  variables {
    lock = {
      kind  = "CanNotDelete"
      notes = "Inherited notes."
    }
    private_endpoints = {
      inherited = {
        name               = "inherited-endpoint"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
      }
      unlocked = {
        name               = "unlocked-endpoint"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        lock = {
          kind = "None"
        }
      }
    }
  }

  assert {
    condition = (
      toset(keys(azapi_resource.private_endpoint_locks)) == toset(["inherited"]) &&
      azapi_resource.private_endpoint_locks["inherited"].body.properties.level == "CanNotDelete" &&
      azapi_resource.private_endpoint_locks["inherited"].body.properties.notes == "Inherited notes." &&
      azurerm_management_lock.this[0].notes == "Inherited notes."
    )
    error_message = "Endpoints must inherit the account lock and notes unless explicitly opted out."
  }
}

run "account_role_settings" {
  command = apply

  variables {
    role_assignments = {
      reader = {
        name                       = "33333333-3333-3333-3333-333333333333"
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-000000000004"
        principal_type             = "Group"
        description                = "Account reader."
      }
    }
  }

  assert {
    condition = (
      azurerm_role_assignment.this["reader"].name == "33333333-3333-3333-3333-333333333333" &&
      azurerm_role_assignment.this["reader"].description == "Account reader." &&
      azurerm_role_assignment.this["reader"].principal_type == "Group" &&
      azurerm_role_assignment.this["reader"].scope == azurerm_batch_account.this.id
    )
    error_message = "The shared role interface must retain name, description, principal type and account scope."
  }
}

run "invalid_subnet" {
  command = plan
  variables {
    private_endpoints = {
      endpoint = { subnet_resource_id = "not-a-resource-id" }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_dns_zone" {
  command = plan
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        private_dns_zone_resource_ids = ["not-a-resource-id"]
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_application_security_group" {
  command = plan
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id                      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        application_security_group_associations = { invalid = "not-a-resource-id" }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_delegated_identity" {
  command = plan
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        role_assignments = {
          reader = {
            role_definition_id_or_name             = "Reader"
            principal_id                           = "00000000-0000-0000-0000-000000000005"
            delegated_managed_identity_resource_id = "not-a-resource-id"
          }
        }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_service" {
  command = plan
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        subresource_name   = "sites"
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_lock" {
  command = plan
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        lock               = { kind = "Invalid" }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_skip_principal_type" {
  command = plan
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/batch-test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoints"
        role_assignments = {
          reader = {
            role_definition_id_or_name       = "Reader"
            principal_id                     = "00000000-0000-0000-0000-000000000006"
            principal_type                   = "Group"
            skip_service_principal_aad_check = true
          }
        }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}
