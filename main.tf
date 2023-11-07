# TODO: insert resources here.

# Azure Load Balancer Module

resource "azurerm_lb" "this" {
  location            = var.location
  name                = var.name
  resource_group_name = var.resource_group_name
  edge_zone           = var.edge_zone
  sku                 = var.sku
  sku_tier            = var.sku_tier
  tags                = var.tags

  dynamic "frontend_ip_configuration" {
    for_each = var.frontend_ip_configurations

    content {
      name                          = coalesce(frontend_ip_configuration.value.name, "frontend-${var.name}")
      private_ip_address            = frontend_ip_configuration.value.frontend_private_ip_address
      private_ip_address_allocation = frontend_ip_configuration.value.frontend_private_ip_address_allocation
      private_ip_address_version    = frontend_ip_configuration.value.frontend_private_ip_address_version
      public_ip_address_id          = frontend_ip_configuration.value.create_public_ip_address ? azurerm_public_ip.azlb[frontend_ip_configuration.value.name].id : frontend_ip_configuration.value.public_ip_address_resource_id
      subnet_id                     = (var.frontend_subnet_resource_id == null || var.frontend_subnet_resource_id == "") && (frontend_ip_configuration.value.frontend_private_ip_subnet_resource_id == null || frontend_ip_configuration.value.frontend_private_ip_subnet_resource_id == "") ? null : coalesce(frontend_ip_configuration.value.frontend_private_ip_subnet_resource_id, var.frontend_subnet_resource_id)
      zones                         = frontend_ip_configuration.value.frontend_ip_zones
    }
  }
}

resource "azurerm_public_ip" "azlb" {
  for_each = { for ip_config in var.frontend_ip_configurations : ip_config.name => ip_config if ip_config.create_public_ip_address }

  allocation_method       = var.public_ip_address_configuration.allocation_method
  location                = coalesce(each.value.new_public_ip_location, var.location)
  name                    = coalesce(each.value.public_ip_address_resource_name, "pip-${var.name}")
  resource_group_name     = coalesce(each.value.new_public_ip_resource_group_name, var.public_ip_address_configuration.resource_group_name, var.resource_group_name)
  ddos_protection_mode    = var.public_ip_address_configuration.ddos_protection_mode             # to be modularized in the future?
  ddos_protection_plan_id = var.public_ip_address_configuration.ddos_protection_plan_resource_id # to be modularized in the future?
  domain_name_label       = var.public_ip_address_configuration.domain_name_label                # to be modularized in the future?
  edge_zone               = each.value.edge_zone
  idle_timeout_in_minutes = var.public_ip_address_configuration.idle_timeout_in_minutes # to be modularized in the future?
  ip_tags                 = var.public_ip_address_configuration.ip_tags                 # to be modularized in the future?
  ip_version              = var.public_ip_address_configuration.ip_version
  public_ip_prefix_id     = var.public_ip_address_configuration.public_ip_prefix_resource_id
  reverse_fqdn            = var.public_ip_address_configuration.reverse_fqdn
  sku                     = var.public_ip_address_configuration.sku
  sku_tier                = var.public_ip_address_configuration.sku_tier
  tags                    = each.value.inherit_tags ? merge(var.public_ip_address_configuration.tags, each.value.tags, var.tags) : merge(var.public_ip_address_configuration.tags, each.value.tags)
  zones                   = each.value.frontend_ip_zones
}





resource "azurerm_lb_backend_address_pool" "azlb" {
  for_each = { for be_pool in var.backend_address_pools : be_pool.name => be_pool }

  loadbalancer_id    = azurerm_lb.this.id
  name               = each.value.name
  virtual_network_id = var.backend_address_pool_configuration
  # to add functionality for tunnel interface
}




resource "azurerm_lb_backend_address_pool_address" "azlb" {
  for_each = { for be_pool_address in var.backend_address_pool_addresses : be_pool_address.name => be_pool_address }

  name                    = each.value.name
  backend_address_pool_id = azurerm_lb_backend_address_pool.azlb[each.value.backend_address_pool_resource_name].id
  virtual_network_id      = var.backend_address_pool_configuration
  ip_address              = each.value.ip_address
}




resource "azurerm_lb_probe" "azlb" {
  for_each = { for probe in var.lb_probes : probe.name => probe }

  loadbalancer_id     = azurerm_lb.this.id
  name                = coalesce(each.value.name, "probe-${var.name}")
  protocol            = each.value.protocol
  port                = each.value.port
  interval_in_seconds = each.value.interval_in_seconds
  probe_threshold     = each.value.probe_threshold
  request_path        = (each.value.protocol == "Http" || each.value.protocol == "Https") ? each.value.request_path : null # request_path is only valid if using `Http` or `Https`
  number_of_probes    = each.value.number_of_probes_before_removal
}




resource "azurerm_lb_rule" "azlb" {
  for_each = { for rule in var.lb_rules : rule.name => rule }

  loadbalancer_id                = azurerm_lb.this.id
  name                           = coalesce(each.value.name, "rule-${var.name}")
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  backend_address_pool_ids       = each.value.backend_address_pool_resource_ids != null || each.value.backend_address_pool_resource_names != null ? coalesce(each.value.backend_address_pool_resource_ids, [for x in each.value.backend_address_pool_resource_names : azurerm_lb_backend_address_pool.azlb[x].id if length(each.value.backend_address_pool_resource_names) > 0]) : null
  probe_id                       = coalesce(azurerm_lb_probe.azlb[each.value.probe_resource_name].id, each.value.probe_resource_id)
  enable_floating_ip             = each.value.enable_floating_ip
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  load_distribution              = each.value.load_distribution
  disable_outbound_snat          = each.value.disable_outbound_snat
  enable_tcp_reset               = each.value.enable_tcp_reset
}




resource "azurerm_lb_nat_rule" "azlb" {
  for_each = { for nat_rule in var.lb_nat_rules : nat_rule.name => nat_rule }

  loadbalancer_id                = azurerm_lb.this.id
  name                           = coalesce(each.value.name, "nat-rule-${var.name}")
  resource_group_name            = var.resource_group_name #data.azurerm_resource_group.azlb.name
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_port_start            = each.value.frontend_port_start
  frontend_port_end              = each.value.frontend_port_end
  backend_address_pool_id        = each.value.backend_address_pool_resource_id != null || each.value.backend_address_pool_resource_name != null ? coalesce(each.value.backend_address_pool_resource_id, azurerm_lb_backend_address_pool.azlb[each.value.backend_address_pool_resource_name].id) : null
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  enable_floating_ip             = each.value.enable_floating_ip
  enable_tcp_reset               = each.value.enable_tcp_reset
}

# To create an outbound rule, the load balancer SKU must be standard and the frontend IP configuration must have at least one public IP address.
resource "azurerm_lb_outbound_rule" "azlb" {
  for_each = { for outbound_rule in var.lb_outbound_rules : outbound_rule.name => outbound_rule }

  loadbalancer_id          = azurerm_lb.this.id
  name                     = coalesce(each.value.name, "outbound-rule-${var.name}")
  backend_address_pool_id  = coalesce(each.value.backend_address_pool_resource_id, azurerm_lb_backend_address_pool.azlb[each.value.backend_address_pool_resource_name].id)
  protocol                 = each.value.protocol
  enable_tcp_reset         = each.value.enable_tcp_reset
  allocated_outbound_ports = each.value.number_of_allocated_outbound_ports
  idle_timeout_in_minutes  = each.value.idle_timeout_in_minutes

  dynamic "frontend_ip_configuration" {
    for_each = each.value.frontend_ip_configurations

    content {
      name = frontend_ip_configuration.value.name
    }
  }
}

# NAT pool
resource "azurerm_lb_nat_pool" "azlb" {
  for_each = { for nat_pool in var.lb_nat_pools : nat_pool.name => nat_pool }

  resource_group_name            = var.resource_group_name #data.azurerm_resource_group.azlb.name
  loadbalancer_id                = azurerm_lb.this.id
  name                           = coalesce(each.value.name, "nat-pool-${var.name}")
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  protocol                       = each.value.protocol
  frontend_port_start            = each.value.frontend_port_start
  frontend_port_end              = each.value.frontend_port_end
  backend_port                   = each.value.backend_port
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  floating_ip_enabled            = each.value.enable_floating_ip
  tcp_reset_enabled              = each.value.enable_tcp_reset
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name
  target_resource_id             = azurerm_lb.this.id
  log_analytics_workspace_id     = each.value.workspace_resource_id
  storage_account_id             = each.value.storage_account_resource_id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  log_analytics_destination_type = each.value.log_analytics_destination_type

  dynamic "enabled_log" {
    for_each = each.value.log_categories

    content {
      category_group = enabled_log.value # category or category_group
    }
  }

  dynamic "enabled_log" {
    for_each = each.value.log_groups

    content {
      category_group = enabled_log.value # category or category_group
    }
  }

  dynamic "metric" {
    for_each = each.value.metric_categories

    content {
      category = metric.value
    }
  }
}

resource "azurerm_management_lock" "azlb" {
  count = var.lock.kind != "None" ? 1 : 0 # only one lock right now, multiple locks needed?

  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_lb.this.id
  lock_level = var.lock.kind
  depends_on = [
    azurerm_lb.this,
    azurerm_public_ip.azlb,
    azurerm_lb_backend_address_pool.azlb,
    azurerm_lb_backend_address_pool_address.azlb,
    azurerm_lb_nat_rule.azlb,
    azurerm_lb_probe.azlb,
    azurerm_lb_rule.azlb,
    azurerm_lb_outbound_rule.azlb,
    azurerm_monitor_diagnostic_setting.this,
    azurerm_role_assignment.this
  ]
}

resource "azurerm_management_lock" "noninherited_pip_lock" {
  for_each = { for ip_config in var.frontend_ip_configurations : ip_config.name => ip_config if ip_config.create_public_ip_address && ip_config.inherit_lock != true && ip_config.lock_type_if_not_inherited != "None" }

  name       = "lock-${each.value.name}"
  scope      = azurerm_public_ip.azlb[each.value.name].id
  lock_level = each.value.lock_type_if_not_inherited
  depends_on = [
    azurerm_lb.this,
    azurerm_public_ip.azlb,
    azurerm_lb_backend_address_pool.azlb,
    azurerm_lb_backend_address_pool_address.azlb,
    azurerm_lb_nat_rule.azlb,
    azurerm_lb_probe.azlb,
    azurerm_lb_rule.azlb,
    azurerm_lb_outbound_rule.azlb,
    azurerm_monitor_diagnostic_setting.this,
    azurerm_role_assignment.this
  ]
}

resource "azurerm_management_lock" "inherited_pip_lock" {
  for_each = { for ip_config in var.frontend_ip_configurations : ip_config.name => ip_config if ip_config.create_public_ip_address && ip_config.inherit_lock && var.lock.kind != "None" }

  name       = coalesce(var.lock.name, "lock-${each.value.name}")
  scope      = azurerm_public_ip.azlb[each.value.name].id
  lock_level = var.lock.kind
  depends_on = [
    azurerm_lb.this,
    azurerm_public_ip.azlb,
    azurerm_lb_backend_address_pool.azlb,
    azurerm_lb_backend_address_pool_address.azlb,
    azurerm_lb_nat_rule.azlb,
    azurerm_lb_probe.azlb,
    azurerm_lb_rule.azlb,
    azurerm_lb_outbound_rule.azlb,
    azurerm_monitor_diagnostic_setting.this,
    azurerm_role_assignment.this
  ]
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                                  = azurerm_lb.this.id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  principal_id                           = each.value.principal_id
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
}
