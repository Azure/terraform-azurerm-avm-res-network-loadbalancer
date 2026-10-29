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
          zones      = frontend.public_ip_address_resource_id != null || frontend.public_ip_prefix_resource_id != null || contains(frontend.zones, "None") ? null : frontend.zones
        }
      ]
      backendAddressPools = [
        for key, pool in var.backend_address_pool_child_modules_enabled ? {} : var.backend_address_pools : { name = pool.name, properties = local.backend_pool_properties[key] }
      ]
      probes             = [for key, probe in var.lb_probes : { name = coalesce(probe.name, "probe-${var.name}"), properties = local.probe_properties[key] }]
      loadBalancingRules = [for key, rule in var.lb_rules : { name = coalesce(rule.name, "rule-${var.name}"), properties = local.rule_properties[key] }]
      inboundNatRules    = []
      outboundRules      = [for key, rule in var.lb_outbound_rules : { name = coalesce(rule.name, "outbound-rule-${var.name}"), properties = local.outbound_rule_properties[key] }]
      inboundNatPools    = local.inbound_nat_pools
    }
  }, var.edge_zone == null ? {} : { extendedLocation = { name = var.edge_zone, type = "EdgeZone" } })
  # On UPDATE AzAPI reads these collections live, strips read-only fields and
  # returns them in the PUT. Omitting them alone would delete child resources.
  ignore_body_changes = distinct(concat(
    ["properties.inboundNatRules"],
    var.backend_address_pool_child_modules_enabled ? ["properties.backendAddressPools"] : [],
    var.ignore_body_changes.network_load_balancers,
  ))
  locks = [local.resource_id]
  replace_triggers_external_values = {
    sku       = var.sku
    sku_tier  = var.sku_tier
    edge_zone = var.edge_zone
  }
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

  lifecycle {
    ignore_changes = [body.properties.inboundNatRules]

    precondition {
      condition     = !var.backend_address_pool_child_modules_enabled || length(setintersection(toset([for id in local.parent_referenced_pool_ids : lower(id)]), toset([for id in values(local.pool_ids) : lower(id)]))) == 0
      error_message = "Child-managed backend pools cannot be referenced by parent-owned load balancing or outbound rules: the parent PUT precedes child creation. Keep those pools inline until a supported staged lifecycle exists."
    }
  }
}

module "backend_address_pool" {
  source   = "./modules/backend-address-pool"
  for_each = var.backend_address_pool_child_modules_enabled ? var.backend_address_pools : {}

  location                      = var.location
  name                          = each.value.name
  parent_id                     = azapi_resource.this.id
  properties                    = local.backend_pool_properties[each.key]
  avm_managed_migration_enabled = var.avm_managed_migration_enabled
  enable_telemetry              = var.enable_telemetry
  ignore_body_changes           = var.ignore_body_changes.network_load_balancers_backend_address_pools
  resource_types                = var.resource_types.network_load_balancers_backend_address_pools
  retry                         = var.retry
  timeouts                      = var.timeouts
}

module "inbound_nat_rule" {
  source   = "./modules/inbound-nat-rule"
  for_each = var.lb_nat_rules

  location                      = var.location
  name                          = coalesce(each.value.name, "nat-rule-${var.name}")
  parent_id                     = azapi_resource.this.id
  properties                    = local.nat_rule_properties[each.key]
  avm_managed_migration_enabled = var.avm_managed_migration_enabled
  enable_telemetry              = var.enable_telemetry
  ignore_body_changes           = var.ignore_body_changes.network_load_balancers_inbound_nat_rules
  resource_types                = var.resource_types.network_load_balancers_inbound_nat_rules
  retry                         = var.retry
  timeouts                      = var.timeouts

  depends_on = [module.backend_address_pool]
}
