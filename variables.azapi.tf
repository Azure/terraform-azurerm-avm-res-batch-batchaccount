variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative dot paths to ignore for private endpoint AzAPI extension resources. Ignored configuration is not sent to Azure until a path is removed. Changes take effect only after apply. Non-empty values require Terraform 1.11 or later.

- `authorization_locks` - Paths ignored on private endpoint locks.
- `authorization_role_assignments` - Paths ignored on private endpoint role assignments.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions for private endpoint extension resources.

- `authorization_locks` - Resource type and API version for private endpoint locks.
- `authorization_role_assignments` - Resource type and API version for private endpoint role assignments.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to private endpoint AzAPI extension resources. Defaults to null.

- `error_message_regex` - Error patterns that trigger a retry.
- `interval_seconds` - Initial interval between retries in seconds.
- `max_interval_seconds` - Maximum interval between retries in seconds.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Per-operation timeouts for private endpoint AzAPI extension resources. Defaults to the provider defaults.

- `create` - Timeout for create operations.
- `read` - Timeout for read operations.
- `update` - Timeout for update operations.
- `delete` - Timeout for delete operations.
DESCRIPTION
}
