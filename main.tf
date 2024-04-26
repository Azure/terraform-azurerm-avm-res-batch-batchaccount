# TODO: Replace this dummy resource azurerm_resource_group.TODO with your module resource
resource "azurerm_resource_group" "TODO" {
  location = var.location
  name     = var.name # calling code must supply the name
}

# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock.kind != "None" ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_resource_group.TODO.id # TODO: Replace this dummy resource azurerm_resource_group.TODO with your module resource
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_resource_group.TODO.id # TODO: Replace this dummy resource azurerm_resource_group.TODO with your module resource
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azurerm_batch_account" "this" {
  location                            = var.location
  name                                = var.name
  resource_group_name                 = var.resource_group_name
  pool_allocation_mode                = var.pool_allocation_mode
  public_network_access_enabled       = var.public_network_access_enabled
  storage_account_authentication_mode = var.storage_account_authentication_mode
  storage_account_id                  = var.storage_account_id
  tags                                = var.tags

  dynamic "identity" {
    for_each = var.identity
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
  dynamic "network_profile" {
    for_each = var.network_profile
    content {
      account_access {
        default_action = network_profile.value.account_access_default_action
      }
      node_management_access {
        default_action = network_profile.value.node_management_access_default_action
      }
    }
  }
}