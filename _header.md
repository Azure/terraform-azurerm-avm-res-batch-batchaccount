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
