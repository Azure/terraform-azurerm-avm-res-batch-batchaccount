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
> This is a breaking upgrade. Legacy duplicate endpoint ownership must be reviewed before applying it; fresh-deployment tests do not establish a state-safe upgrade.

This module requires AzureRM v4 and Terraform 1.9 or later. The Batch account and existing endpoint resource addresses are unchanged. Correcting a previously ignored service or IP member can replace the affected endpoint. The full `resource` output is sensitive because it includes Batch access keys.

With `private_endpoints_manage_dns_zone_group = false`, legacy deployments can record both addresses for the same map key:

- `azurerm_private_endpoint.this_managed_dns_zone_groups["<key>"]`
- `azurerm_private_endpoint.this_unmanaged_dns_zone_groups["<key>"]`

The duplicate-owner condition is:

```text
azurerm_private_endpoint.this_managed_dns_zone_groups["<key>"].id
  == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["<key>"].id
```

The corrected DNS-off behavior creates only the unmanaged endpoint. If both legacy addresses own the same Azure resource ID, removing the managed address can delete the shared endpoint even while the unmanaged address remains. Do not apply the upgrade until this ownership has been reconciled and the upgrade risk acknowledged. Both address labels and DNS lifecycle modes are retained; this module does not perform automatic state moves, removal or deletion to reconcile legacy ownership.
