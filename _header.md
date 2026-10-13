# Terraform Azure Batch Account Module

This Terraform module is designed to create and manage Azure Batch Accounts and their associated resources. Azure Batch is a cloud-based job scheduling service that enables you to run large-scale parallel and high-performance computing applications efficiently on Azure.

> [!WARNING]
> Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. A module SHOULD NOT be considered stable until at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to <https://semver.org/>

## Features

* Create and manage Azure Batch Accounts
* Supports customer-managed keys for encryption
* Enable private endpoints for secure network access
* Apply locks to protect resources from accidental deletion
* Configure role-based access control (RBAC) for fine-grained permissions
* Integration with Azure diagnostics and monitoring capabilities

## Limitations

* Batch Account names must be unique within the Azure region
* Some features may require specific subscriptions or regions where the service is available

## Private endpoints

Each endpoint connects to `subresource_name` (`batchAccount` by default, or `nodeManagement`). Static IP configurations use that service and honor `member_name`, defaulting it to the service name. Supply distinct endpoint and connection names when creating multiple endpoints. Endpoint tags inherit `tags` unless an override is supplied.

Endpoints inherit the account lock when no endpoint lock is supplied. Use `lock = { kind = "None" }` on an endpoint to opt out. Endpoint role assignments and lock notes are applied to the endpoint resource.

## Upgrade notes

> [!WARNING]
> This is a breaking upgrade. Resolve any legacy duplicate endpoint ownership before applying it. Fresh mocked tests do not prove a safe upgrade of an existing deployment's state.

This module requires AzureRM v4 and Terraform 1.9 or later. The Batch account and existing endpoint resource addresses are unchanged. Correcting a previously ignored service or IP member can replace the affected endpoint. The full `resource` output is sensitive because it includes Batch access keys.

### DNS-off duplicate endpoint ownership

An existing deployment is affected by this issue only when `private_endpoints_manage_dns_zone_group = false` and **both** managed/unmanaged state addresses for the same endpoint key exist and have the **same Azure endpoint ID**. A single binding or two different IDs does not meet this condition; do not use the state-removal procedure below in those cases.

For a caller named `module.azure_batch_account` (as in the default example) and endpoint key `account`, the affected addresses are:

- `module.azure_batch_account.azurerm_private_endpoint.this_managed_dns_zone_groups["account"]`
- `module.azure_batch_account.azurerm_private_endpoint.this_unmanaged_dns_zone_groups["account"]`

The duplicate-owner condition is equality of the `id` fields recorded at these two addresses. Substitute your exact caller module path and endpoint key; if the module is used as the root configuration, omit `module.azure_batch_account.`.

The corrected DNS-off behavior retains only the unmanaged endpoint. An upgrade plan can therefore destroy the duplicate managed owner, deleting the shared Azure endpoint even though the unmanaged state binding remains. Both address labels and DNS lifecycle modes are retained; the module does not automatically reconcile existing state.

Before applying the upgrade, the deployment owner must perform this manual prerequisite:

1. Stop concurrent Terraform runs and confirm the correct backend/workspace. Securely back up the current state outside the repository using an access-restricted or encrypted location; state can contain secrets. Confirm that the backup can be restored.
1. Inspect only the two exact endpoint instances and verify their IDs are identical. Confirm that the unmanaged binding is the intended retained endpoint and that the corrected configuration still uses the same key with DNS management disabled. In PowerShell 7.4 or later, the example inspections are:

   ```powershell
   terraform state show 'module.azure_batch_account.azurerm_private_endpoint.this_managed_dns_zone_groups["account"]'
   terraform state show 'module.azure_batch_account.azurerm_private_endpoint.this_unmanaged_dns_zone_groups["account"]'
   ```

1. **Only if those checks confirm duplicate ownership**, preview removal and confirm that it selects only the duplicate managed instance. Then remove that one managed **state binding**, not the Azure endpoint. Leave the unmanaged binding unchanged:

   ```powershell
   terraform state rm -dry-run 'module.azure_batch_account.azurerm_private_endpoint.this_managed_dns_zone_groups["account"]'
   terraform state rm 'module.azure_batch_account.azurerm_private_endpoint.this_managed_dns_zone_groups["account"]'
   ```

1. Rerun `terraform plan` against the corrected configuration and review it before any apply. **Do not apply any unexpected endpoint deletion or recreation**, including replacements caused by corrected service/IP settings; stop and resolve the discrepancy first.

[`terraform state rm`](https://developer.hashicorp.com/terraform/cli/commands/state/rm) forgets only the selected binding without deleting the remote object. Never use a whole-module/resource address, wildcard, or blanket removal for this prerequisite, and do not apply the old configuration after forgetting its managed binding. These are conditional operator instructions, not an automatic migration or a guarantee that an existing-state upgrade is safe.
