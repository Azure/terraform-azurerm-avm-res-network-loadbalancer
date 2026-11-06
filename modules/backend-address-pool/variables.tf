variable "location" {
  type        = string
  description = "The Azure region for this module's resources or telemetry deployment."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The backend address pool name."
  nullable    = false
}

variable "parent_id" {
  type        = string
  description = "The parent load balancer resource ID."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers", var.parent_id))
    error_message = "The parent must be a valid load balancer resource ID."
  }
}

variable "properties" {
  type = object({
    virtualNetwork = optional(object({ id = string }))
    tunnelInterfaces = optional(list(object({
      identifier = number
      port       = number
      protocol   = string
      type       = string
    })), [])
    loadBalancerBackendAddresses = optional(list(object({
      name = string
      properties = object({
        ipAddress                           = optional(string)
        virtualNetwork                      = optional(object({ id = string }))
        loadBalancerFrontendIPConfiguration = optional(object({ id = string }))
      })
    })), [])
  })
  description = "Writable pool ARM properties: virtualNetwork ID object, tunnelInterfaces (identifier/port/protocol/type), and authoritative loadBalancerBackendAddresses. Each member has name and properties containing exactly one of ipAddress (optional virtualNetwork ID object) or loadBalancerFrontendIPConfiguration ID object. Frontend members require Global tier/Frontend mode and no VNet. NIC mode requires an empty input list and omits the server projection; NIC ownership remains external."
  nullable    = false

  validation {
    condition = alltrue([for a in var.properties.loadBalancerBackendAddresses :
      (a.properties.ipAddress == null ? 0 : 1) + (a.properties.loadBalancerFrontendIPConfiguration == null ? 0 : 1) == 1 &&
      (a.properties.loadBalancerFrontendIPConfiguration == null || a.properties.virtualNetwork == null) &&
      (a.properties.loadBalancerFrontendIPConfiguration == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/frontendIPConfigurations", a.properties.loadBalancerFrontendIPConfiguration.id))) &&
      (a.properties.ipAddress == null ? true : can(cidrhost("${a.properties.ipAddress}/${strcontains(a.properties.ipAddress, ":") ? 128 : 32}", 0)))
    ])
    error_message = "Each member requires exactly one valid IP address or valid regional LB frontend resource ID; frontend members cannot specify a VNet."
  }
  validation {
    condition = (
      length(distinct([for a in var.properties.loadBalancerBackendAddresses : a.name])) == length(var.properties.loadBalancerBackendAddresses) &&
      (var.backend_address_type != "NIC" || length(var.properties.loadBalancerBackendAddresses) == 0) &&
      alltrue([for a in var.properties.loadBalancerBackendAddresses : (var.backend_address_type == "Frontend") == (a.properties.loadBalancerFrontendIPConfiguration != null)])
    )
    error_message = "Member names must be unique, NIC-mode lists empty, and IP/Frontend member forms must match backend_address_type."
  }
  validation {
    condition = (
      (var.properties.virtualNetwork == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.properties.virtualNetwork.id))) &&
      alltrue([for a in var.properties.loadBalancerBackendAddresses : a.properties.virtualNetwork == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", a.properties.virtualNetwork.id))])
    )
    error_message = "Pool and address virtual network IDs must be valid virtual network resource IDs."
  }
}

variable "avm_managed_migration_enabled" {
  type        = bool
  default     = false
  description = "Import an existing pool at parent_id/backendAddressPools/name without deleting it. Enable only for adoption, never fresh creation; disable after convergence."
  nullable    = false
}

variable "backend_address_type" {
  type        = string
  default     = "NIC"
  description = "NIC (default for omission/null) omits the projection and creates no explicit-member cleanup, leaving memberships to the NIC owner. Opt into IP or Frontend to own an explicit list with fixed-empty destroy cleanup. Keep existing IP pools explicitly IP; clear explicit members before changing to NIC, and detach NICs before changing from NIC."
  nullable    = false

  validation {
    condition     = contains(["IP", "NIC", "Frontend"], var.backend_address_type)
    error_message = "backend_address_type must be IP, NIC or Frontend."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "ignore_body_changes" {
  type = object({
    network_load_balancers_backend_address_pools = optional(list(string), [])
  })
  default     = {}
  description = "Body-relative dot paths. `network_load_balancers_backend_address_pools` contains pool paths to ignore. NIC references are omitted from writes; live membership preservation requires real-Azure verification. Ignored configuration is not sent to Azure; changes take effect after apply."
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_load_balancers_backend_address_pools = optional(string, "Microsoft.Network/loadBalancers/backendAddressPools@2025-01-01")
  })
  default     = {}
  description = "Resource API versions. `network_load_balancers_backend_address_pools` is the backend pool ARM resource type and API version."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = "Resource retry controls: error_message_regex, interval_seconds and max_interval_seconds."
}

variable "sku_tier" {
  type        = string
  default     = "Regional"
  description = "Declaration of the externally owned parent LB tier, Regional or Global. The caller must match its actual SKU and use public Standard regional frontend IDs for Global members; this module does not inspect remote parents."
  nullable    = false

  validation {
    condition     = contains(["Regional", "Global"], var.sku_tier)
    error_message = "sku_tier must be Regional or Global."
  }
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = "Per-operation create, read, update and delete timeouts as Go duration strings."
}
