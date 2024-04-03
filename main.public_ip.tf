resource "azurerm_public_ip" "this" {
  for_each = { for frontend, frontend_values in var.frontend_ip_configurations : frontend => frontend_values if frontend_values.create_public_ip_address }

  allocation_method       = var.public_ip_address_configuration.allocation_method
  location                = coalesce(each.value.new_public_ip_location, var.location)
  name                    = coalesce(each.value.public_ip_address_resource_name, "pip-${var.name}")
  resource_group_name     = coalesce(each.value.new_public_ip_resource_group_name, var.public_ip_address_configuration.resource_group_name, var.resource_group_name)
  ddos_protection_mode    = var.public_ip_address_configuration.ddos_protection_mode
  ddos_protection_plan_id = var.public_ip_address_configuration.ddos_protection_plan_resource_id
  domain_name_label       = var.public_ip_address_configuration.domain_name_label
  edge_zone               = each.value.edge_zone
  idle_timeout_in_minutes = var.public_ip_address_configuration.idle_timeout_in_minutes
  ip_tags                 = var.public_ip_address_configuration.ip_tags
  ip_version              = var.public_ip_address_configuration.ip_version
  public_ip_prefix_id     = var.public_ip_address_configuration.public_ip_prefix_resource_id
  reverse_fqdn            = var.public_ip_address_configuration.reverse_fqdn
  sku                     = var.public_ip_address_configuration.sku
  sku_tier                = var.public_ip_address_configuration.sku_tier
  tags                    = each.value.inherit_tags ? merge(var.public_ip_address_configuration.tags, each.value.tags, var.tags) : merge(var.public_ip_address_configuration.tags, each.value.tags)
  zones                   = contains(each.value.zones, "None") ? null : each.value.zones
}
