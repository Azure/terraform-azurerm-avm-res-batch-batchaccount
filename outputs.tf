output "resource" {
  description = "This is the full output for the resource."
  sensitive   = true
  value       = azurerm_batch_account.this
}

output "resource_id" {
  description = "The ID of the Batch account created."
  value       = azurerm_batch_account.this.id
}

output "resource_private_endpoints" {
  description = "A map of private endpoints. The map key is the supplied input to var.private_endpoints. The map value is the entire azurerm_private_endpoint resource."
  value       = local.private_endpoint_resources
}
