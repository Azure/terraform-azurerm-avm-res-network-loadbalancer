variable "ignore_body_changes" {
  type = object({
    network_load_balancers         = optional(list(string), [])
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    insights_diagnostic_settings   = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative dot paths to ignore. Configuration for ignored paths is not sent to Azure; changes take effect after apply.
List indices are unsupported. All LB child collections are authoritative by default. Ignoring a collection disables management of its configured changes; do not use this to hide convergence defects.
- `network_load_balancers` - LB body paths.
- `authorization_locks` - Lock paths.
- `authorization_role_assignments` - RBAC paths.
- `insights_diagnostic_settings` - Diagnostic paths.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_load_balancers         = optional(string, "Microsoft.Network/loadBalancers@2025-01-01")
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    insights_diagnostic_settings   = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions.
- `network_load_balancers` - Primary load balancer.
- `authorization_locks` - Resource locks.
- `authorization_role_assignments` - RBAC assignments.
- `insights_diagnostic_settings` - Diagnostic settings (the API only provides a preview version).

Inline LB collections use the parent resource API version.
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
Retry configuration applied to every `azapi` resource managed by the module (root resource and all submodules). Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
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
Default per-operation timeouts applied to every `azapi` resource managed by the module. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
