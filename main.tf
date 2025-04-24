# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_batch_account.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_batch_account.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

# Azure Batch Account Resource
resource "azurerm_batch_account" "this" {
  location                            = var.location
  name                                = var.name
  resource_group_name                 = var.resource_group_name
  allowed_authentication_modes        = var.allowed_authentication_modes
  pool_allocation_mode                = var.pool_allocation_mode
  public_network_access_enabled       = var.public_network_access_enabled
  storage_account_authentication_mode = var.storage_account_authentication_mode
  storage_account_id                  = var.storage_account_id
  storage_account_node_identity       = var.storage_account_node_identity
  tags                                = var.tags != null ? var.tags : {}

  # Dynamic block for encryption
  dynamic "encryption" {
    for_each = var.encryption != null ? [var.encryption] : []

    content {
      key_vault_key_id = encryption.value.key_vault_key_id
    }
  }
  # Dynamic block for identity
  dynamic "identity" {
    for_each = var.identity

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
  # Dynamic block for key_vault_reference (required when pool_allocation_mode = "UserSubscription")
  dynamic "key_vault_reference" {
    for_each = var.key_vault_reference != null ? [var.key_vault_reference] : []

    content {
      id  = key_vault_reference.value.id
      url = key_vault_reference.value.url
    }
  }
  # Dynamic block for network_profile
  dynamic "network_profile" {
    for_each = var.network_profile

    content {
      dynamic "account_access" {
        for_each = network_profile.value.account_access != null ? [network_profile.value.account_access] : []

        content {
          default_action = account_access.value.default_action

          dynamic "ip_rule" {
            for_each = account_access.value.ip_rules != null ? account_access.value.ip_rules : {}

            content {
              ip_range = ip_rule.value.ip_range
              action   = ip_rule.value.action
            }
          }
        }
      }
      dynamic "node_management_access" {
        for_each = network_profile.value.node_management_access != null ? [network_profile.value.node_management_access] : []

        content {
          default_action = node_management_access.value.default_action

          dynamic "ip_rule" {
            for_each = node_management_access.value.ip_rules != null ? node_management_access.value.ip_rules : {}

            content {
              ip_range = ip_rule.value.ip_range
              action   = ip_rule.value.action
            }
          }
        }
      }
    }
  }
}
