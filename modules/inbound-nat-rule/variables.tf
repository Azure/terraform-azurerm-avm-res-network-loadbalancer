variable "location" {
  type        = string
  description = "The Azure region for this module's resources or telemetry deployment."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The inbound NAT rule name."
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
    frontendIPConfiguration = object({ id = string })
    backendAddressPool      = optional(object({ id = string }))
    protocol                = optional(string, "Tcp")
    frontendPort            = optional(number)
    frontendPortRangeStart  = optional(number)
    frontendPortRangeEnd    = optional(number)
    backendPort             = number
    enableFloatingIP        = optional(bool, false)
    enableTcpReset          = optional(bool, false)
    idleTimeoutInMinutes    = optional(number, 4)
  })
  description = "NAT ARM properties: frontendIPConfiguration and optional backendAddressPool ID objects, protocol, frontendPort or frontendPortRangeStart/End, backendPort, enableFloatingIP, enableTcpReset and idleTimeoutInMinutes."
  nullable    = false

  validation {
    condition = (
      can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/frontendIPConfigurations", var.properties.frontendIPConfiguration.id)) &&
      (var.properties.backendAddressPool == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/backendAddressPools", var.properties.backendAddressPool.id)))
    )
    error_message = "NAT frontend and backend pool IDs must match their ARM resource types."
  }
}

variable "avm_managed_migration_enabled" {
  type        = bool
  default     = false
  description = "Import an existing rule at parent_id/inboundNatRules/name without deleting it. Enable only for adoption, never fresh creation; disable after convergence."
  nullable    = false
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
    network_load_balancers_inbound_nat_rules = optional(list(string), [])
  })
  default     = {}
  description = "Body-relative dot paths. `network_load_balancers_inbound_nat_rules` contains NAT rule paths to ignore. Ignored configuration is not sent to Azure; changes take effect after apply."
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_load_balancers_inbound_nat_rules = optional(string, "Microsoft.Network/loadBalancers/inboundNatRules@2025-01-01")
  })
  default     = {}
  description = "Resource API versions. `network_load_balancers_inbound_nat_rules` is the NAT rule ARM resource type and API version."
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
