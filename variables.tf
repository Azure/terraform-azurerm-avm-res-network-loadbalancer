variable "frontend_ip_configurations" {
  type = map(object({
    name                                               = optional(string)
    frontend_private_ip_address                        = optional(string)
    frontend_private_ip_address_version                = optional(string, "IPv4")
    frontend_private_ip_address_allocation             = optional(string, "Dynamic")
    frontend_private_ip_subnet_resource_id             = optional(string)
    gateway_load_balancer_frontend_ip_configuration_id = optional(string)
    public_ip_address_resource_id                      = optional(string)
    public_ip_prefix_resource_id                       = optional(string)
    zones                                              = optional(list(string), ["1", "2", "3"])
  }))
  description = <<DESCRIPTION
Frontend configurations keyed by stable consumer keys. `name` defaults to frontend-<LB name>; names must be unique.
Supply one of public_ip_address_resource_id, public_ip_prefix_resource_id, or a subnet.
PIPs are consumer-owned; creation, PIP tags, DNS, DDoS, zones and PIP extension resources belong in that composition.
Private frontends support frontend_private_ip_address, frontend_private_ip_address_allocation (Dynamic/Static),
frontend_private_ip_address_version (IPv4/IPv6) and frontend_private_ip_subnet_resource_id.
gateway_load_balancer_frontend_ip_configuration_id chains a Gateway LB frontend.
zones defaults to 1/2/3 for private frontends; ["None"] omits zones. Public frontends inherit PIP zones.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.frontend_ip_configurations) > 0 && length(distinct([for v in var.frontend_ip_configurations : coalesce(v.name, "frontend-${var.name}")])) == length(var.frontend_ip_configurations)
    error_message = "At least one frontend is required and resolved frontend names must be unique."
  }
  validation {
    condition = alltrue([for v in var.frontend_ip_configurations :
      contains(["Dynamic", "Static"], v.frontend_private_ip_address_allocation) &&
      contains(["IPv4", "IPv6"], v.frontend_private_ip_address_version) &&
      (v.frontend_private_ip_address_allocation != "Static" || v.frontend_private_ip_address != null)
    ])
    error_message = "Private IP allocation must be Dynamic or Static, IP version IPv4 or IPv6, and Static requires an address."
  }
  validation {
    condition = alltrue([for v in var.frontend_ip_configurations :
      (v.frontend_private_ip_subnet_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", v.frontend_private_ip_subnet_resource_id))) &&
      (v.public_ip_address_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPAddresses", v.public_ip_address_resource_id))) &&
      (v.public_ip_prefix_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPPrefixes", v.public_ip_prefix_resource_id))) &&
      (v.gateway_load_balancer_frontend_ip_configuration_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/frontendIPConfigurations", v.gateway_load_balancer_frontend_ip_configuration_id)))
    ])
    error_message = "Frontend subnet, public IP, public IP prefix and gateway frontend IDs must have the expected ARM resource types."
  }
  validation {
    condition = alltrue([for v in var.frontend_ip_configurations :
      (v.public_ip_address_resource_id != null ? 1 : 0) +
      (v.public_ip_prefix_resource_id != null ? 1 : 0) +
      (v.frontend_private_ip_subnet_resource_id != null || var.frontend_subnet_resource_id != null ? 1 : 0) == 1
    ])
    error_message = "Each frontend requires exactly one public IP, public IP prefix, or subnet."
  }
}

variable "location" {
  type        = string
  description = "The Azure region in which to deploy the load balancer."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The load balancer name. Names are provided by the consumer."
  nullable    = false
}

variable "parent_id" {
  type        = string
  description = "The fully-qualified resource ID of the existing resource group."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid resource group resource ID."
  }
}

variable "backend_address_pool_addresses" {
  type = map(object({
    name                                                = string
    backend_address_pool_object_name                    = string
    ip_address                                          = optional(string)
    virtual_network_resource_id                         = optional(string)
    load_balancer_frontend_ip_configuration_resource_id = optional(string)
  }))
  default     = {}
  description = "Explicit backend members by stable key. name and backend_address_pool_object_name (pool input key) are required. Supply exactly one of ip_address (IP mode, with optional virtual_network_resource_id overriding pool/default VNet) or load_balancer_frontend_ip_configuration_resource_id (Frontend mode on a Global LB, referencing a public regional LB frontend). Frontend members cannot specify a VNet. A dedicated refreshing pool endpoint owns this authoritative list, including [] for last-member removal. Native NIC memberships require a separate NIC-mode pool and remain owned by the NIC owner."
  nullable    = false

  validation {
    condition = alltrue([for a in var.backend_address_pool_addresses :
      (a.ip_address == null ? 0 : 1) + (a.load_balancer_frontend_ip_configuration_resource_id == null ? 0 : 1) == 1 &&
      (a.load_balancer_frontend_ip_configuration_resource_id == null || a.virtual_network_resource_id == null)
    ])
    error_message = "Each backend member requires exactly one IP address or regional LB frontend ID; frontend members cannot specify a VNet."
  }
  validation {
    condition = alltrue([for a in var.backend_address_pool_addresses :
      a.load_balancer_frontend_ip_configuration_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/frontendIPConfigurations", a.load_balancer_frontend_ip_configuration_resource_id))
    ])
    error_message = "Frontend member IDs must identify Microsoft.Network/loadBalancers/frontendIPConfigurations."
  }
  validation {
    condition = alltrue([for a in var.backend_address_pool_addresses :
      a.ip_address == null || can(cidrhost("${a.ip_address}/${strcontains(a.ip_address, ":") ? 128 : 32}", 0))
    ])
    error_message = "ip_address must be a valid IPv4 or IPv6 address."
  }
  validation {
    condition = alltrue([for a in var.backend_address_pool_addresses :
      try((var.backend_address_pools[a.backend_address_pool_object_name].backend_address_type == "Frontend") == (a.load_balancer_frontend_ip_configuration_resource_id != null), true)
    ])
    error_message = "Frontend-mode pools accept only frontend references; IP-mode pools accept only IP addresses."
  }
  validation {
    condition     = alltrue([for v in var.backend_address_pool_addresses : contains(keys(var.backend_address_pools), v.backend_address_pool_object_name)])
    error_message = "Every backend address must reference a configured backend pool key."
  }
  validation {
    condition     = alltrue([for v in var.backend_address_pool_addresses : v.virtual_network_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", v.virtual_network_resource_id))])
    error_message = "Backend address virtual network IDs must be valid virtual network resource IDs."
  }
  validation {
    condition     = length(distinct([for v in var.backend_address_pool_addresses : "${v.backend_address_pool_object_name}/${v.name}"])) == length(var.backend_address_pool_addresses)
    error_message = "Address names must be unique within each pool."
  }
  validation {
    condition = alltrue([for address in var.backend_address_pool_addresses : try(var.backend_address_pools[address.backend_address_pool_object_name].backend_address_type != "NIC", true)])
    error_message = format(
      "Azure does not allow IP-address members and native NIC associations in the same backend pool (CannotMixIPBasedAddressesAndIPConfigurationsOnLoadBalancerBackendAddressPool). Conflicting backend_address_pool_addresses keys -> NIC-mode pool keys: %s. Put these IP members in a separate pool with backend_address_type = \"IP\". Keep backend_address_type = \"NIC\" on pools whose memberships are configured by the NIC owner using backend_address_pool_resource_ids. Both pool types can coexist on the same load balancer.",
      join(", ", [for key, address in var.backend_address_pool_addresses : format("'%s' -> '%s'", key, address.backend_address_pool_object_name) if try(var.backend_address_pools[address.backend_address_pool_object_name].backend_address_type == "NIC", false)])
    )
  }
}

variable "backend_address_pool_configuration" {
  type        = string
  default     = null
  description = "Default virtual network resource ID for IP-based backend pools and addresses."

  validation {
    condition     = var.backend_address_pool_configuration == null || can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.backend_address_pool_configuration))
    error_message = "The backend pool default must be a virtual network resource ID."
  }
}

variable "backend_address_pools" {
  type = map(object({
    name                        = optional(string, "bepool-1")
    backend_address_type        = optional(string, "NIC")
    virtual_network_resource_id = optional(string)
    tunnel_interfaces = optional(map(object({
      identifier = number
      port       = number
      protocol   = string
      type       = string
    })), {})
  }))
  default     = {}
  description = "Backend pools by stable input key: unique name, backend_address_type (NIC default for omission/null, IP, or Frontend), optional virtual_network_resource_id and tunnel_interfaces (identifier, port, protocol, type). The parent owns metadata, not member lists. NIC creates no explicit-member writer or cleanup; membership remains exclusively with the NIC owner. Opt into IP for explicit addresses. Dedicated endpoints authoritatively manage IP/Frontend members, including [] to clear the last member and fixed-empty destroy cleanup. Global pools require explicit Frontend mode and no VNet/tunnels; regional pools require IP or NIC. Modes declare ownership, not an Azure conversion: keep existing IP pools explicitly IP; clear explicit members before switching to NIC; detach native NICs before switching from NIC. Coordinate mode changes separately."
  nullable    = false

  validation {
    condition     = length(distinct([for v in var.backend_address_pools : v.name])) == length(var.backend_address_pools)
    error_message = "Backend pool names must be unique."
  }
  validation {
    condition = alltrue([for pool in var.backend_address_pools : contains(["IP", "NIC", "Frontend"], pool.backend_address_type)])
    error_message = format(
      "backend_address_type must be exactly \"IP\", \"NIC\" or \"Frontend\". Invalid pool keys: %s. Use IP for explicit addresses, NIC for native memberships configured by the NIC owner, and Frontend for regional LB frontends on Global LBs. Different member types require separate pools.",
      join(", ", [for key, pool in var.backend_address_pools : key if !contains(["IP", "NIC", "Frontend"], pool.backend_address_type)])
    )
  }
  validation {
    condition     = alltrue([for v in var.backend_address_pools : v.virtual_network_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", v.virtual_network_resource_id))])
    error_message = "Pool virtual network IDs must be valid virtual network resource IDs."
  }
  validation {
    condition = alltrue(flatten([for v in var.backend_address_pools : [for t in v.tunnel_interfaces :
      contains(["Internal", "External"], t.type) && contains(["None", "Native", "VXLAN"], t.protocol) && t.port >= 0 && t.port <= 65535 && t.identifier >= 0
    ]]))
    error_message = "Tunnel type must be Internal/External, protocol None/Native/VXLAN, and port and identifier must be nonnegative and in range."
  }
}

variable "edge_zone" {
  type        = string
  default     = null
  description = "Optional edge zone. Changing the edge zone replaces the load balancer."
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

variable "frontend_subnet_resource_id" {
  type        = string
  default     = null
  description = "Default subnet resource ID for private frontends."

  validation {
    condition     = var.frontend_subnet_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", var.frontend_subnet_resource_id))
    error_message = "The default frontend subnet must be a valid subnet resource ID."
  }
}

variable "lb_nat_pools" {
  type = map(object({
    name                           = optional(string)
    frontend_ip_configuration_name = string
    protocol                       = optional(string, "Tcp")
    frontend_port_start            = optional(number, 3000)
    frontend_port_end              = optional(number, 3389)
    backend_port                   = optional(number, 3389)
    idle_timeout_in_minutes        = optional(number, 4)
    enable_floating_ip             = optional(bool, false)
    enable_tcp_reset               = optional(bool, false)
  }))
  default     = {}
  description = "Inline VMSS NAT pools (not deployable ARM subresources). Fields: name, frontend_ip_configuration_name, protocol, frontend_port_start/end, backend_port, idle_timeout_in_minutes, enable_floating_ip and enable_tcp_reset. Mutually exclusive with lb_nat_rules. Prefer NAT v2 rules for new deployments."
  nullable    = false

  validation {
    condition     = length(var.lb_nat_pools) == 0 || length(var.lb_nat_rules) == 0
    error_message = "Inbound NAT pools and inbound NAT rules are mutually exclusive."
  }
  validation {
    condition = alltrue([for r in var.lb_nat_pools :
      contains(["Tcp", "Udp"], r.protocol) && r.frontend_port_start >= 1 && r.frontend_port_end <= 65535 &&
      r.frontend_port_start <= r.frontend_port_end && r.backend_port >= 1 && r.backend_port <= 65535 &&
      r.idle_timeout_in_minutes >= 4 && r.idle_timeout_in_minutes <= 30 &&
      contains([for f in var.frontend_ip_configurations : coalesce(f.name, "frontend-${var.name}")], r.frontend_ip_configuration_name)
    ])
    error_message = "NAT pool protocol, port range, timeout or frontend reference is invalid."
  }
}

variable "lb_nat_rules" {
  type = map(object({
    name                             = optional(string)
    frontend_ip_configuration_name   = string
    protocol                         = optional(string, "Tcp")
    frontend_port                    = optional(number)
    backend_port                     = number
    frontend_port_start              = optional(number)
    frontend_port_end                = optional(number)
    backend_address_pool_resource_id = optional(string)
    backend_address_pool_object_name = optional(string)
    idle_timeout_in_minutes          = optional(number, 4)
    enable_floating_ip               = optional(bool, false)
    enable_tcp_reset                 = optional(bool, false)
  }))
  default     = {}
  description = "Inbound NAT rules by stable input key. Specify name (default nat-rule-<LB name>), frontend_ip_configuration_name, protocol, backend_port, and either frontend_port (v1) or frontend_port_start/end plus a backend pool reference (v2). Supports idle_timeout_in_minutes, enable_floating_ip and enable_tcp_reset."
  nullable    = false

  validation {
    condition = alltrue([for r in var.lb_nat_rules :
      contains(["Tcp", "Udp", "All"], r.protocol) && r.backend_port >= 1 && r.backend_port <= 65535 &&
      r.idle_timeout_in_minutes >= 4 && r.idle_timeout_in_minutes <= 30 &&
      (r.backend_address_pool_object_name == null || r.backend_address_pool_resource_id == null) &&
      (r.frontend_port != null ? r.frontend_port_start == null && r.frontend_port_end == null : r.frontend_port_start != null && r.frontend_port_end != null) &&
      (r.frontend_port == null ? (r.backend_address_pool_object_name != null || r.backend_address_pool_resource_id != null) : true)
    ])
    error_message = "NAT rules require valid protocol/ports/timeout and exactly one scalar port or port-range mode; range mode requires a pool."
  }
  validation {
    condition = alltrue([for r in var.lb_nat_rules :
      contains([for f in var.frontend_ip_configurations : coalesce(f.name, "frontend-${var.name}")], r.frontend_ip_configuration_name) &&
      (r.backend_address_pool_object_name == null ? true : contains(keys(var.backend_address_pools), r.backend_address_pool_object_name)) &&
      (r.backend_address_pool_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/backendAddressPools", r.backend_address_pool_resource_id)))
    ])
    error_message = "NAT rule frontend and pool references must be valid."
  }
  validation {
    condition     = length(distinct([for r in var.lb_nat_rules : coalesce(r.name, "nat-rule-${var.name}")])) == length(var.lb_nat_rules)
    error_message = "Resolved NAT rule names must be unique."
  }
}

variable "lb_outbound_rules" {
  type = map(object({
    name                               = optional(string)
    frontend_ip_configurations         = list(object({ name = string }))
    backend_address_pool_resource_id   = optional(string)
    backend_address_pool_object_name   = optional(string)
    protocol                           = optional(string, "Tcp")
    enable_tcp_reset                   = optional(bool, false)
    number_of_allocated_outbound_ports = optional(number, 1024)
    idle_timeout_in_minutes            = optional(number, 4)
  }))
  default     = {}
  description = "Outbound rules by stable input key. Supply frontend_ip_configurations (list of Azure names), one backend pool resource ID or object key, protocol, enable_tcp_reset, number_of_allocated_outbound_ports and idle_timeout_in_minutes. name defaults to outbound-rule-<LB name>."
  nullable    = false

  validation {
    condition = alltrue([for r in var.lb_outbound_rules :
      contains(["Tcp", "Udp", "All"], r.protocol) && r.idle_timeout_in_minutes >= 4 && r.idle_timeout_in_minutes <= 120 &&
      r.number_of_allocated_outbound_ports >= 0 && r.number_of_allocated_outbound_ports <= 64000 &&
      (r.backend_address_pool_object_name != null) != (r.backend_address_pool_resource_id != null) &&
      length(r.frontend_ip_configurations) > 0 &&
      alltrue([for f in r.frontend_ip_configurations : contains([for v in var.frontend_ip_configurations : coalesce(v.name, "frontend-${var.name}")], f.name)]) &&
      (r.backend_address_pool_object_name == null ? true : contains(keys(var.backend_address_pools), r.backend_address_pool_object_name)) &&
      (r.backend_address_pool_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/backendAddressPools", r.backend_address_pool_resource_id)))
    ])
    error_message = "Outbound rules require valid frontend names, exactly one valid pool reference, protocol, ports and timeout."
  }
  validation {
    condition     = length(distinct([for r in var.lb_outbound_rules : coalesce(r.name, "outbound-rule-${var.name}")])) == length(var.lb_outbound_rules)
    error_message = "Resolved outbound rule names must be unique."
  }
}

variable "lb_probes" {
  type = map(object({
    name                            = optional(string)
    protocol                        = optional(string, "Tcp")
    port                            = optional(number, 80)
    interval_in_seconds             = optional(number, 15)
    number_of_probes_before_removal = optional(number, 2)
    probe_threshold                 = optional(number, 1)
    request_path                    = optional(string)
  }))
  default     = {}
  description = "Health probes: unique name (default probe-<LB name>), protocol Tcp/Http/Https, port, interval_in_seconds, number_of_probes_before_removal, probe_threshold and HTTP/S request_path."
  nullable    = false

  validation {
    condition = alltrue([for p in var.lb_probes :
      contains(["Tcp", "Http", "Https"], p.protocol) && p.port >= 1 && p.port <= 65535 &&
      p.interval_in_seconds >= 5 && p.number_of_probes_before_removal >= 2 &&
      p.probe_threshold >= 1 && p.probe_threshold <= 100 &&
      (p.protocol == "Tcp" ? p.request_path == null : p.request_path != null)
    ])
    error_message = "Probes require valid protocol/port, interval >=5, number of probes >=2, threshold 1-100 and a path only for HTTP/S."
  }
  validation {
    condition     = length(distinct([for p in var.lb_probes : coalesce(p.name, "probe-${var.name}")])) == length(var.lb_probes)
    error_message = "Resolved probe names must be unique."
  }
}

variable "lb_rules" {
  type = map(object({
    name                              = optional(string)
    frontend_ip_configuration_name    = string
    protocol                          = optional(string, "Tcp")
    frontend_port                     = optional(number, 3389)
    backend_port                      = optional(number, 3389)
    backend_address_pool_resource_ids = optional(list(string))
    backend_address_pool_object_names = optional(list(string))
    probe_resource_id                 = optional(string)
    probe_object_name                 = optional(string)
    enable_floating_ip                = optional(bool, false)
    idle_timeout_in_minutes           = optional(number, 4)
    load_distribution                 = optional(string, "Default")
    disable_outbound_snat             = optional(bool, false)
    enable_tcp_reset                  = optional(bool, false)
  }))
  default     = {}
  description = "Load balancing rules by input key. frontend_ip_configuration_name is an Azure frontend name. Supply backend_address_pool_resource_ids or backend_address_pool_object_names (keys), and optionally probe_resource_id or probe_object_name (key). Supports protocol, frontend_port, backend_port, enable_floating_ip, idle_timeout_in_minutes, load_distribution, disable_outbound_snat and enable_tcp_reset. name defaults to rule-<LB name>."
  nullable    = false

  validation {
    condition = alltrue([for r in var.lb_rules :
      contains(["Tcp", "Udp", "All"], r.protocol) &&
      contains(["Default", "SourceIP", "SourceIPProtocol"], r.load_distribution) &&
      r.idle_timeout_in_minutes >= 4 && r.idle_timeout_in_minutes <= 100 &&
      r.frontend_port >= 0 && r.frontend_port <= 65535 && r.backend_port >= 0 && r.backend_port <= 65535 &&
      (r.probe_object_name == null || r.probe_resource_id == null) &&
      (r.backend_address_pool_object_names == null || r.backend_address_pool_resource_ids == null)
    ])
    error_message = "Rule protocol, distribution, ports or idle timeout are invalid, or mutually exclusive references were supplied."
  }
  validation {
    condition = alltrue([for r in var.lb_rules :
      contains([for f in var.frontend_ip_configurations : coalesce(f.name, "frontend-${var.name}")], r.frontend_ip_configuration_name) &&
      (r.probe_object_name == null ? true : contains(keys(var.lb_probes), r.probe_object_name)) &&
      alltrue([for k in coalesce(r.backend_address_pool_object_names, []) : contains(keys(var.backend_address_pools), k)])
    ])
    error_message = "Rule frontend names, pool keys and probe keys must reference configured objects."
  }
  validation {
    condition = alltrue([for r in var.lb_rules :
      (r.probe_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/probes", r.probe_resource_id))) &&
      alltrue([for id in coalesce(r.backend_address_pool_resource_ids, []) : can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/backendAddressPools", id))])
    ])
    error_message = "Rule probe and backend pool IDs must be valid IDs of the expected ARM types."
  }
  validation {
    condition     = length(distinct([for r in var.lb_rules : coalesce(r.name, "rule-${var.name}")])) == length(var.lb_rules)
    error_message = "Resolved load balancing rule names must be unique."
  }
}

variable "sku" {
  type        = string
  default     = "Standard"
  description = "Standard or Gateway. Changing SKU replaces the load balancer."
  nullable    = false

  validation {
    condition     = contains(["Standard", "Gateway"], var.sku)
    error_message = "SKU must be Standard or Gateway."
  }
}

variable "sku_tier" {
  type        = string
  default     = "Regional"
  description = "Regional or Global. Changing tier replaces the load balancer."
  nullable    = false

  validation {
    condition     = contains(["Regional", "Global"], var.sku_tier)
    error_message = "SKU tier must be Regional or Global."
  }
  validation {
    condition = var.sku_tier != "Global" || (
      var.sku == "Standard" &&
      length(var.lb_probes) == 0 &&
      length(var.lb_nat_rules) == 0 &&
      length(var.lb_nat_pools) == 0 &&
      length(var.lb_outbound_rules) == 0 &&
      alltrue([for r in var.lb_rules : r.probe_object_name == null && r.probe_resource_id == null && r.protocol != "All" && !(r.protocol == "Udp" && (r.frontend_port == 3 || r.backend_port == 3))]) &&
      alltrue([for f in var.frontend_ip_configurations :
        f.public_ip_address_resource_id != null &&
        f.frontend_private_ip_address == null &&
        f.frontend_private_ip_subnet_resource_id == null &&
        f.gateway_load_balancer_frontend_ip_configuration_id == null
      ]) &&
      var.frontend_subnet_resource_id == null
    )
    error_message = "Global LBs require Standard SKU and public-IP frontends. Configure only load-balancing rules: no health probes (including rule probe references), NAT pools/rules, outbound rules, Gateway chaining, All protocol or UDP port 3. Health is inherited from regional LBs."
  }
  validation {
    condition = alltrue([for p in var.backend_address_pools :
      var.sku_tier == "Global" ?
      (p.backend_address_type == "Frontend" && p.virtual_network_resource_id == null && var.backend_address_pool_configuration == null && length(p.tunnel_interfaces) == 0) :
      p.backend_address_type != "Frontend"
    ])
    error_message = "Global pools require backend_address_type = \"Frontend\" with no VNet/tunnels; Frontend mode is not supported on Regional LBs."
  }
  validation {
    condition = var.sku_tier != "Global" || alltrue([for r in var.lb_rules :
      r.frontend_port == r.backend_port && !r.enable_tcp_reset &&
      length(r.backend_address_pool_resource_ids != null ? r.backend_address_pool_resource_ids : coalesce(r.backend_address_pool_object_names, [])) == 1
    ])
    error_message = "Global rules require matching frontend_port and backend_port, enable_tcp_reset = false, and exactly one backend pool reference (serialized as backendAddressPool). Azure rejects Global port translation and TCP reset."
  }
}
