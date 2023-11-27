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
      public_ip_address_id          = frontend_ip_configuration.value.create_public_ip_address ? azurerm_public_ip.this[frontend_ip_configuration.key].id : frontend_ip_configuration.value.public_ip_address_resource_id
      subnet_id                     = (var.frontend_subnet_resource_id == null || var.frontend_subnet_resource_id == "") && (frontend_ip_configuration.value.frontend_private_ip_subnet_resource_id == null || frontend_ip_configuration.value.frontend_private_ip_subnet_resource_id == "") ? null : coalesce(frontend_ip_configuration.value.frontend_private_ip_subnet_resource_id, var.frontend_subnet_resource_id)
      zones                         = frontend_ip_configuration.value.frontend_ip_zones
    }
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  for_each = var.backend_address_pools

  loadbalancer_id    = azurerm_lb.this.id
  name               = each.value.name
  virtual_network_id = var.backend_address_pool_configuration
  # to add functionality for tunnel interface
}

resource "azurerm_lb_backend_address_pool_address" "this" {
  for_each = { for be_pool_address in var.backend_address_pool_addresses : be_pool_address.name => be_pool_address }

  name                    = each.value.name
  backend_address_pool_id = azurerm_lb_backend_address_pool.this[each.value.backend_address_pool_object_name].id
  virtual_network_id      = var.backend_address_pool_configuration
  ip_address              = each.value.ip_address
}

resource "azurerm_lb_probe" "this" {
  for_each = var.lb_probes

  loadbalancer_id     = azurerm_lb.this.id
  name                = coalesce(each.value.name, "probe-${var.name}")
  protocol            = each.value.protocol
  port                = each.value.port
  interval_in_seconds = each.value.interval_in_seconds
  probe_threshold     = each.value.probe_threshold
  request_path        = (each.value.protocol == "Http" || each.value.protocol == "Https") ? each.value.request_path : null
  number_of_probes    = each.value.number_of_probes_before_removal
}

resource "azurerm_lb_rule" "this" {
  for_each = var.lb_rules

  loadbalancer_id                = azurerm_lb.this.id
  name                           = coalesce(each.value.name, "rule-${var.name}")
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  backend_address_pool_ids       = each.value.backend_address_pool_resource_ids != null || each.value.backend_address_pool_object_names != null ? coalesce(each.value.backend_address_pool_resource_ids, [for x in each.value.backend_address_pool_object_names : azurerm_lb_backend_address_pool.this[x].id if length(each.value.backend_address_pool_object_names) > 0]) : null
  probe_id                       = coalesce(azurerm_lb_probe.this[each.value.probe_object_name].id, each.value.probe_resource_id)
  enable_floating_ip             = each.value.enable_floating_ip
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  load_distribution              = each.value.load_distribution
  disable_outbound_snat          = each.value.disable_outbound_snat
  enable_tcp_reset               = each.value.enable_tcp_reset
}

resource "azurerm_lb_nat_rule" "this" {
  for_each = { for nat_rule in var.lb_nat_rules : nat_rule.name => nat_rule }

  loadbalancer_id                = azurerm_lb.this.id
  name                           = coalesce(each.value.name, "nat-rule-${var.name}")
  resource_group_name            = var.resource_group_name
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_port_start            = each.value.frontend_port_start
  frontend_port_end              = each.value.frontend_port_end
  backend_address_pool_id        = each.value.backend_address_pool_resource_id != null || each.value.backend_address_pool_object_name != null ? coalesce(each.value.backend_address_pool_resource_id, azurerm_lb_backend_address_pool.this[each.value.backend_address_pool_object_name].id) : null
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  enable_floating_ip             = each.value.enable_floating_ip
  enable_tcp_reset               = each.value.enable_tcp_reset
}

# To create an outbound rule, the load balancer SKU must be standard and the frontend IP configuration must have at least one public IP address.
resource "azurerm_lb_outbound_rule" "this" {
  for_each = { for outbound_rule in var.lb_outbound_rules : outbound_rule.name => outbound_rule }

  loadbalancer_id          = azurerm_lb.this.id
  name                     = coalesce(each.value.name, "outbound-rule-${var.name}")
  backend_address_pool_id  = coalesce(each.value.backend_address_pool_resource_id, azurerm_lb_backend_address_pool.this[each.value.backend_address_pool_object_name].id)
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

resource "azurerm_lb_nat_pool" "this" {
  for_each = { for nat_pool in var.lb_nat_pools : nat_pool.name => nat_pool }

  resource_group_name            = var.resource_group_name
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
