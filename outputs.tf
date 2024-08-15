output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_batch_account.this
}

output "resource_id" {
  description = "The ID of the Batch account created."
  value       = azurerm_batch_account.this.id
}

output "resource_private_endpoints" {
  description = "A map of private endpoints. The map key is the supplied input to var.private_endpoints. The map value is the entire azurerm_private_endpoint resource."
  value       = var.private_endpoints_manage_dns_zone_group ? azurerm_private_endpoint.this_managed_dns_zone_groups : azurerm_private_endpoint.this_unmanaged_dns_zone_groups
}
