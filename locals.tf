locals {
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

locals {
  private_endpoint_resources = merge(
    azurerm_private_endpoint.this_managed_dns_zone_groups,
    azurerm_private_endpoint.this_unmanaged_dns_zone_groups
  )
  private_endpoint_interfaces = {
    for key, endpoint in var.private_endpoints : key => merge(endpoint, {
      lock = try(endpoint.lock.kind, null) == "None" ? null : (
        endpoint.lock != null ? endpoint.lock : var.lock
      )
      role_assignments = {
        for assignment_key, assignment in endpoint.role_assignments : assignment_key => merge(assignment, {
          principal_type = assignment.principal_type != null ? assignment.principal_type : (
            assignment.skip_service_principal_aad_check ? "ServicePrincipal" : null
          )
        })
      }
    })
  }
  private_endpoint_application_security_group_associations = { for assoc in flatten([
    for pe_k, pe_v in var.private_endpoints : [
      for asg_k, asg_v in pe_v.application_security_group_associations : {
        asg_key         = asg_k
        pe_key          = pe_k
        asg_resource_id = asg_v
      }
    ]
  ]) : "${assoc.pe_key}-${assoc.asg_key}" => assoc }
}
