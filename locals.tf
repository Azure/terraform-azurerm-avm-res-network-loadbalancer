locals {
  resource_id = "${var.parent_id}/providers/Microsoft.Network/loadBalancers/${var.name}"
  frontend_ids = {
    for key, frontend in var.frontend_ip_configurations : key => "${local.resource_id}/frontendIPConfigurations/${coalesce(frontend.name, "frontend-${var.name}")}"
  }
  pool_ids = {
    for key, pool in var.backend_address_pools : key => "${local.resource_id}/backendAddressPools/${pool.name}"
  }
  probe_ids = {
    for key, probe in var.lb_probes : key => "${local.resource_id}/probes/${coalesce(probe.name, "probe-${var.name}")}"
  }
  frontend_properties = {
    for key, frontend in var.frontend_ip_configurations : key => {
      privateIPAddress          = frontend.frontend_private_ip_address
      privateIPAllocationMethod = frontend.public_ip_address_resource_id != null || frontend.public_ip_prefix_resource_id != null ? null : frontend.frontend_private_ip_address_allocation
      privateIPAddressVersion   = frontend.public_ip_address_resource_id != null || frontend.public_ip_prefix_resource_id != null ? null : coalesce(frontend.frontend_private_ip_address_version, "IPv4")
      subnet                    = coalesce(frontend.frontend_private_ip_subnet_resource_id, var.frontend_subnet_resource_id, "unset") == "unset" ? null : { id = coalesce(frontend.frontend_private_ip_subnet_resource_id, var.frontend_subnet_resource_id) }
      publicIPAddress           = frontend.public_ip_address_resource_id == null ? null : { id = frontend.public_ip_address_resource_id }
      publicIPPrefix            = frontend.public_ip_prefix_resource_id == null ? null : { id = frontend.public_ip_prefix_resource_id }
      gatewayLoadBalancer       = frontend.gateway_load_balancer_frontend_ip_configuration_id == null ? null : { id = frontend.gateway_load_balancer_frontend_ip_configuration_id }
    }
  }
  backend_pool_properties = {
    for key, pool in var.backend_address_pools : key => {
      virtualNetwork = coalesce(pool.virtual_network_resource_id, var.backend_address_pool_configuration, "unset") == "unset" ? null : { id = coalesce(pool.virtual_network_resource_id, var.backend_address_pool_configuration) }
      tunnelInterfaces = [
        for tunnel in values(pool.tunnel_interfaces) : {
          identifier = tunnel.identifier
          port       = tunnel.port
          protocol   = tunnel.protocol
          type       = tunnel.type
        }
      ]
    }
  }
  # Never include these lists in the parent PUT. Only the dedicated pool
  # endpoint persists explicit members reliably. NIC projections are read-only.
  backend_pool_members = {
    for key, pool in var.backend_address_pools : key => [
      for address in values(var.backend_address_pool_addresses) : {
        name = address.name
        properties = merge(
          pool.backend_address_type == "Frontend" ? { loadBalancerFrontendIPConfiguration = { id = address.load_balancer_frontend_ip_configuration_resource_id } } : {},
          pool.backend_address_type == "IP" ? { ipAddress = address.ip_address } : {},
          pool.backend_address_type == "IP" && coalesce(address.virtual_network_resource_id, pool.virtual_network_resource_id, var.backend_address_pool_configuration, "unset") != "unset" ? {
            virtualNetwork = { id = coalesce(address.virtual_network_resource_id, pool.virtual_network_resource_id, var.backend_address_pool_configuration, "unset") }
          } : {}
        )
      } if address.backend_address_pool_object_name == key
    ] if pool.backend_address_type != "NIC"
  }
  probe_properties = {
    for key, probe in var.lb_probes : key => {
      protocol          = probe.protocol
      port              = probe.port
      intervalInSeconds = probe.interval_in_seconds
      numberOfProbes    = probe.number_of_probes_before_removal
      probeThreshold    = probe.probe_threshold
      requestPath       = probe.request_path
    }
  }
  rule_properties = {
    for key, rule in var.lb_rules : key => {
      frontendIPConfiguration = { id = "${local.resource_id}/frontendIPConfigurations/${rule.frontend_ip_configuration_name}" }
      backendAddressPools     = var.sku_tier == "Global" ? null : [for id in sort(distinct(rule.backend_address_pool_resource_ids != null ? rule.backend_address_pool_resource_ids : [for key in coalesce(rule.backend_address_pool_object_names, []) : local.pool_ids[key]])) : { id = id }]
      backendAddressPool      = var.sku_tier != "Global" ? null : try({ id = (rule.backend_address_pool_resource_ids != null ? rule.backend_address_pool_resource_ids : [for key in coalesce(rule.backend_address_pool_object_names, []) : local.pool_ids[key]])[0] }, null)
      probe                   = rule.probe_resource_id != null ? { id = rule.probe_resource_id } : rule.probe_object_name != null ? { id = local.probe_ids[rule.probe_object_name] } : null
      protocol                = rule.protocol
      frontendPort            = rule.frontend_port
      backendPort             = rule.backend_port
      enableFloatingIP        = rule.enable_floating_ip
      idleTimeoutInMinutes    = rule.idle_timeout_in_minutes
      loadDistribution        = rule.load_distribution
      disableOutboundSnat     = rule.disable_outbound_snat
      enableTcpReset          = rule.enable_tcp_reset
    }
  }
  nat_rule_properties = {
    for key, rule in var.lb_nat_rules : key => {
      frontendIPConfiguration = { id = "${local.resource_id}/frontendIPConfigurations/${rule.frontend_ip_configuration_name}" }
      backendAddressPool      = rule.backend_address_pool_resource_id != null ? { id = rule.backend_address_pool_resource_id } : rule.backend_address_pool_object_name != null ? { id = local.pool_ids[rule.backend_address_pool_object_name] } : null
      protocol                = rule.protocol
      frontendPort            = rule.frontend_port
      frontendPortRangeStart  = rule.frontend_port_start
      frontendPortRangeEnd    = rule.frontend_port_end
      backendPort             = rule.backend_port
      enableFloatingIP        = rule.enable_floating_ip
      enableTcpReset          = rule.enable_tcp_reset
      idleTimeoutInMinutes    = rule.idle_timeout_in_minutes
    }
  }
  outbound_rule_properties = {
    for key, rule in var.lb_outbound_rules : key => {
      frontendIPConfigurations = [for name in sort(distinct([for frontend in rule.frontend_ip_configurations : frontend.name])) : { id = "${local.resource_id}/frontendIPConfigurations/${name}" }]
      backendAddressPool       = { id = rule.backend_address_pool_resource_id != null ? rule.backend_address_pool_resource_id : local.pool_ids[rule.backend_address_pool_object_name] }
      protocol                 = rule.protocol
      allocatedOutboundPorts   = rule.number_of_allocated_outbound_ports
      enableTcpReset           = rule.enable_tcp_reset
      idleTimeoutInMinutes     = rule.idle_timeout_in_minutes
    }
  }
  # All collections and their references are sent in the same complete LB PUT.
  inbound_nat_pools = [
    for key, pool in var.lb_nat_pools : {
      name = coalesce(pool.name, "nat-pool-${var.name}")
      properties = {
        frontendIPConfiguration = { id = "${local.resource_id}/frontendIPConfigurations/${pool.frontend_ip_configuration_name}" }
        protocol                = pool.protocol
        frontendPortRangeStart  = pool.frontend_port_start
        frontendPortRangeEnd    = pool.frontend_port_end
        backendPort             = pool.backend_port
        enableFloatingIP        = pool.enable_floating_ip
        enableTcpReset          = pool.enable_tcp_reset
        idleTimeoutInMinutes    = pool.idle_timeout_in_minutes
      }
    }
  ]
}
