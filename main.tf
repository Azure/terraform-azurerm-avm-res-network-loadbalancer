resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_load_balancers
  body = merge({
    sku = { name = var.sku, tier = var.sku_tier }
    properties = {
      frontendIPConfigurations = [
        for key, frontend in var.frontend_ip_configurations : {
          name       = coalesce(frontend.name, "frontend-${var.name}")
          properties = local.frontend_properties[key]
          zones      = frontend.public_ip_address_resource_id != null || frontend.public_ip_prefix_resource_id != null || contains(frontend.zones, "None") ? null : sort(distinct(frontend.zones))
        }
      ]
      backendAddressPools = [
        for key, pool in var.backend_address_pools : { name = pool.name, properties = local.backend_pool_properties[key] }
      ]
      probes             = [for key, probe in var.lb_probes : { name = coalesce(probe.name, "probe-${var.name}"), properties = local.probe_properties[key] }]
      loadBalancingRules = [for key, rule in var.lb_rules : { name = coalesce(rule.name, "rule-${var.name}"), properties = local.rule_properties[key] }]
      inboundNatRules    = [for key, rule in var.lb_nat_rules : { name = coalesce(rule.name, "nat-rule-${var.name}"), properties = local.nat_rule_properties[key] }]
      outboundRules      = [for key, rule in var.lb_outbound_rules : { name = coalesce(rule.name, "outbound-rule-${var.name}"), properties = local.outbound_rule_properties[key] }]
      inboundNatPools    = local.inbound_nat_pools
    }
  }, var.edge_zone == null ? {} : { extendedLocation = { name = var.edge_zone, type = "EdgeZone" } })
  ignore_body_changes = length(var.ignore_body_changes.network_load_balancers) > 0 ? var.ignore_body_changes.network_load_balancers : null
  # All child collections are authoritative, including empty lists for removal.
  # Null optional fields mean unspecified, not an instruction to clear defaults.
  ignore_null_property = true
  locks                = [local.resource_id]
  # Retain this stable shape for experimental-draft state continuity. Edge-zone
  # null transitions must replace too; an optional body path cannot express that.
  replace_triggers_external_values = {
    sku       = var.sku
    sku_tier  = var.sku_tier
    edge_zone = var.edge_zone
  }
  replace_triggers_refs = [
    "sku.name",
    "sku.tier",
  ]
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }

  }
}
