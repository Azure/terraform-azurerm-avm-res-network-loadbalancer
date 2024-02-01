resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = azurerm_lb.this.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  log_analytics_destination_type = each.value.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.log_groups

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.metric_categories

    content {
      category = metric.value
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "pip" {
  for_each = local.pip_diagnostic_settings

  name                           = each.value.diagnostic_setting.name != null ? each.value.diagnostic_setting.name : "diag-${var.name}"
  target_resource_id             = azurerm_public_ip.this[each.value.frontend_key].id
  eventhub_authorization_rule_id = each.value.diagnostic_setting.event_hub_authorization_rule_resource_id
  log_analytics_destination_type = each.value.diagnostic_setting.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.diagnostic_setting.workspace_resource_id
  partner_solution_id            = each.value.diagnostic_setting.marketplace_partner_resource_id
  storage_account_id             = each.value.diagnostic_setting.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.diagnostic_setting.log_categories

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.diagnostic_setting.log_groups

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.diagnostic_setting.metric_categories

    content {
      category = metric.value
    }
  }
}
