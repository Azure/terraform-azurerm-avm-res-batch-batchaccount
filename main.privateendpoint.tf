resource "azurerm_private_endpoint" "this_managed_dns_zone_groups" {
  for_each = { for k, v in var.private_endpoints : k => v if var.private_endpoints_manage_dns_zone_group }

  location                      = each.value.location != null ? each.value.location : var.location
  name                          = each.value.name != null ? each.value.name : "pe-${var.name}"
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags != null ? each.value.tags : var.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}"
    private_connection_resource_id = azurerm_batch_account.this.id
    subresource_names              = [coalesce(each.value.subresource_name, "batchAccount")]
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = coalesce(ip_configuration.value.member_name, each.value.subresource_name, "batchAccount")
      subresource_name   = coalesce(each.value.subresource_name, "batchAccount")
    }
  }

  dynamic "private_dns_zone_group" {
    for_each = length(each.value.private_dns_zone_resource_ids) > 0 ? ["this"] : []

    content {
      name                 = each.value.private_dns_zone_group_name
      private_dns_zone_ids = each.value.private_dns_zone_resource_ids
    }
  }
}

resource "azurerm_private_endpoint" "this_unmanaged_dns_zone_groups" {
  for_each = { for k, v in var.private_endpoints : k => v if !var.private_endpoints_manage_dns_zone_group }

  location                      = each.value.location != null ? each.value.location : var.location
  name                          = each.value.name != null ? each.value.name : "pe-${var.name}"
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags != null ? each.value.tags : var.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}"
    private_connection_resource_id = azurerm_batch_account.this.id
    subresource_names              = [coalesce(each.value.subresource_name, "batchAccount")]
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = coalesce(ip_configuration.value.member_name, each.value.subresource_name, "batchAccount")
      subresource_name   = coalesce(each.value.subresource_name, "batchAccount")
    }
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}

resource "azurerm_private_endpoint_application_security_group_association" "this" {
  for_each = local.private_endpoint_application_security_group_associations

  application_security_group_id = each.value.asg_resource_id
  private_endpoint_id           = local.private_endpoint_resources[each.value.pe_key].id
}

module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  location                         = var.location
  enable_telemetry                 = var.enable_telemetry
  private_endpoints                = local.private_endpoint_interfaces
  private_endpoints_scope          = azurerm_batch_account.this.id
  role_assignment_definition_scope = azurerm_batch_account.this.id
}

resource "azapi_resource" "private_endpoint_role_assignments" {
  for_each = module.avm_interfaces.role_assignments_private_endpoint_azapi

  name                = each.value.name
  parent_id           = local.private_endpoint_resources[each.value.pe_key].id
  type                = var.resource_types.authorization_role_assignments
  body                = each.value.body
  ignore_body_changes = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "private_endpoint_locks" {
  for_each = module.avm_interfaces.lock_private_endpoint_azapi

  name      = coalesce(each.value.name, "lock-${each.value.body.properties.level}")
  parent_id = local.private_endpoint_resources[each.value.pe_key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = merge(each.value.body.properties, {
      notes = local.private_endpoint_interfaces[each.key].lock.notes
    })
  }
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  depends_on = [
    azurerm_private_endpoint_application_security_group_association.this,
    azapi_resource.private_endpoint_role_assignments,
  ]
}
