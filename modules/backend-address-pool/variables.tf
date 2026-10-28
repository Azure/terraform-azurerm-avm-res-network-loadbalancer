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
        ipAddress      = string
        virtualNetwork = optional(object({ id = string }))
      })
    })), [])
  })
  description = "Writable pool ARM properties: virtualNetwork ID object, tunnelInterfaces (identifier/port/protocol/type), and authoritative loadBalancerBackendAddresses (name, properties.ipAddress and properties.virtualNetwork ID). NIC membership remains external."
  nullable    = false

  validation {
    condition = (
      (var.properties.virtualNetwork == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.properties.virtualNetwork.id))) &&
      alltrue([for a in var.properties.loadBalancerBackendAddresses : a.properties.virtualNetwork == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", a.properties.virtualNetwork.id))])
    )
    error_message = "Pool and address virtual network IDs must be valid virtual network resource IDs."
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
