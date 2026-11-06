# Contract/request tests only: mocks do not prove service acceptance, removal,
# lock ordering, imported identity or provider-private ignore behavior.
mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = { output = { results = [] } }
  }
}

mock_provider "random" {}

mock_provider "time" {}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
  }
}

variables {
  name             = "lab"
  location         = "eastus2"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab"
  enable_telemetry = false
  frontend_ip_configurations = {
    public = {
      public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/public"
    }
  }
}

run "partner_only_and_explicit_null_defaults" {
  command = apply
  variables {
    diagnostic_settings = {
      partner = {
        marketplace_partner_resource_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Datadog/monitors/partner"
        name                                     = null
        logs                                     = null
        metrics                                  = null
        log_analytics_destination_type           = null
        workspace_resource_id                    = null
        storage_account_resource_id              = null
        event_hub_authorization_rule_resource_id = null
        event_hub_name                           = null
      }
    }
  }
  assert {
    condition = (
      azapi_resource.diagnostic_settings["partner"].name == "diag-lab" &&
      azapi_resource.diagnostic_settings["partner"].parent_id == azapi_resource.this.id &&
      azapi_resource.diagnostic_settings["partner"].body.properties.marketplacePartnerId == var.diagnostic_settings.partner.marketplace_partner_resource_id &&
      azapi_resource.diagnostic_settings["partner"].body.properties.logAnalyticsDestinationType == "Dedicated" &&
      azapi_resource.diagnostic_settings["partner"].body.properties.logs == null &&
      azapi_resource.diagnostic_settings["partner"].body.properties.metrics == null &&
      azapi_resource.diagnostic_settings["partner"].body.properties.workspaceId == null &&
      azapi_resource.diagnostic_settings["partner"].body.properties.storageAccountId == null &&
      azapi_resource.diagnostic_settings["partner"].body.properties.eventHubAuthorizationRuleId == null &&
      azapi_resource.diagnostic_settings["partner"].body.properties.eventHubName == null
    )
    error_message = "A polymorphic partner alone is a destination; null optional collections default empty then utility v2 emits null, not an explicit clear."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "diagnostic_entry_defaults_and_null_retention" {
  command = apply
  variables {
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/logs"
        logs = [
          { category = "LoadBalancerHealthEvent", enabled = null, retention_policy = null },
          { category_group = "allLogs", enabled = false, retention_policy = { days = 14, enabled = true } },
        ]
        metrics = [{ category = "AllMetrics", enabled = null, retention_policy = {} }]
      }
    }
  }
  assert {
    condition = (
      length(azapi_resource.diagnostic_settings["workspace"].body.properties.logs) == 2 &&
      alltrue([for l in azapi_resource.diagnostic_settings["workspace"].body.properties.logs :
        l.category == "LoadBalancerHealthEvent" ?
        l.enabled && l.categoryGroup == null && l.retentionPolicy.days == 0 && !l.retentionPolicy.enabled :
        !l.enabled && l.categoryGroup == "allLogs" && l.retentionPolicy.days == 14 && l.retentionPolicy.enabled
      ]) &&
      azapi_resource.diagnostic_settings["workspace"].body.properties.metrics[0].enabled &&
      azapi_resource.diagnostic_settings["workspace"].body.properties.metrics[0].retentionPolicy.days == 0 &&
      !azapi_resource.diagnostic_settings["workspace"].body.properties.metrics[0].retentionPolicy.enabled
    )
    error_message = "Nested null/default retention and enabled flags must use canonical defaults without losing explicit false or categoryGroup casing."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_empty_diagnostic_entries_are_utility_nulls" {
  command = apply
  variables {
    diagnostic_settings = {
      storage = {
        storage_account_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Storage/storageAccounts/logs"
        logs                        = []
        metrics                     = []
      }
    }
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["storage"].body.properties.logs == null && azapi_resource.diagnostic_settings["storage"].body.properties.metrics == null && azapi_resource.diagnostic_settings["storage"].body.properties.workspaceId == null
    error_message = "The canonical utility maps empty entry sets to null; do not claim these are explicit ARM [] removals."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "minimal_rbac_omits_optional_properties" {
  command = apply
  variables {
    role_assignments = {
      reader = {
        name                       = "33333333-3333-3333-3333-333333333333"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "22222222-2222-2222-2222-222222222222"
      }
    }
  }
  assert {
    condition = (
      azapi_resource.role_assignments["reader"].name == var.role_assignments.reader.name &&
      azapi_resource.role_assignments["reader"].parent_id == azapi_resource.this.id &&
      length(data.azapi_resource_list.role_definitions) == 0 &&
      azapi_resource.role_assignments["reader"].ignore_casing &&
      azapi_resource.role_assignments["reader"].ignore_null_property &&
      alltrue([for k in ["principalType", "description", "condition", "conditionVersion", "delegatedManagedIdentityResourceId"] :
        azapi_resource.role_assignments["reader"].body.properties[k] == null
      ]) &&
      azapi_resource.role_assignments["reader"].replace_triggers_external_values.principal_type == null &&
      length(azapi_resource.lock) == 0 && length(time_sleep.lock_removal) == 0
    )
    error_message = "Explicit IDs must bypass lookup; omitted RBAC options remain null and are omitted on the wire, without a lock barrier."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_principal_overrides_skip_check_with_lock" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete", name = null, notes = null }
    role_assignments = {
      user = {
        name                                   = "44444444-4444-4444-4444-444444444444"
        role_definition_id_or_name             = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id                           = "22222222-2222-2222-2222-222222222222"
        principal_type                         = "User"
        skip_service_principal_aad_check       = true
        description                            = "Preserved description"
        condition                              = "test-condition"
        condition_version                      = "2.0"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
      }
    }
  }
  assert {
    condition = (
      azapi_resource.role_assignments["user"].body.properties.principalType == "User" &&
      azapi_resource.role_assignments["user"].body.properties.description == var.role_assignments.user.description &&
      azapi_resource.role_assignments["user"].body.properties.condition == var.role_assignments.user.condition &&
      azapi_resource.role_assignments["user"].body.properties.conditionVersion == "2.0" &&
      azapi_resource.role_assignments["user"].body.properties.delegatedManagedIdentityResourceId == var.role_assignments.user.delegated_managed_identity_resource_id &&
      azapi_resource.role_assignments["user"].replace_triggers_external_values.condition == var.role_assignments.user.condition &&
      azapi_resource.role_assignments["user"].replace_triggers_external_values.delegated_managed_identity_resource_id == var.role_assignments.user.delegated_managed_identity_resource_id &&
      azapi_resource.role_assignments["user"].replace_triggers_external_values.principal_type == "User" &&
      azapi_resource.lock[0].name == "lock-lab" &&
      time_sleep.lock_removal[0].triggers.resource_id == azapi_resource.this.id
    )
    error_message = "Explicit principal type wins over skip-check fallback; optional RBAC properties and replacement inputs coexist with the lock."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "unresolved_role_name_fails_before_assignment" {
  command = plan
  variables {
    role_assignments = {
      missing = { role_definition_id_or_name = "NoSuchRole", principal_id = "22222222-2222-2222-2222-222222222222" }
    }
  }
  expect_failures = [azapi_resource.role_assignments["missing"]]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "extension_resource_control_overrides" {
  command = apply
  variables {
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "22222222-2222-2222-2222-222222222222"
      }
    }
    diagnostic_settings = {
      metrics = { marketplace_partner_resource_id = "/providers/vendor/type/partner" }
    }
    resource_types = {
      network_load_balancers         = "Microsoft.Network/loadBalancers@2024-10-01"
      authorization_locks            = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
      insights_diagnostic_settings   = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
    }
    retry    = { error_message_regex = ["RetryableError"] }
    timeouts = { read = "7m", update = "43m" }
  }
  assert {
    condition = (
      azapi_resource.this.type == var.resource_types.network_load_balancers &&
      azapi_resource.lock[0].type == var.resource_types.authorization_locks &&
      azapi_resource.role_assignments["reader"].type == var.resource_types.authorization_role_assignments &&
      azapi_resource.diagnostic_settings["metrics"].type == var.resource_types.insights_diagnostic_settings &&
      azapi_resource.lock[0].body.properties.notes == "Cannot delete or modify the resource or its child resources."
    )
    error_message = "Each root/extension must receive its own API override and unchanged partial retry/timeouts; API acceptance and write-only ignores need separate proof."
  }
  assert {
    condition = (
      azapi_resource.this.retry.error_message_regex == var.retry.error_message_regex &&
      azapi_resource.lock[0].retry.error_message_regex == var.retry.error_message_regex &&
      azapi_resource.role_assignments["reader"].retry.error_message_regex == var.retry.error_message_regex &&
      azapi_resource.diagnostic_settings["metrics"].retry.error_message_regex == var.retry.error_message_regex &&
      var.retry.interval_seconds == null && var.retry.max_interval_seconds == null &&
      azapi_resource.this.timeouts == var.timeouts &&
      azapi_resource.lock[0].timeouts == var.timeouts &&
      azapi_resource.role_assignments["reader"].timeouts == var.timeouts &&
      azapi_resource.diagnostic_settings["metrics"].timeouts == var.timeouts
    )
    error_message = "Partial retry/timeouts must reach each resource; optional computed retry values belong to the provider, not the canonical input."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "consumer_ignore_paths_accepted" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "22222222-2222-2222-2222-222222222222"
      }
    }
    diagnostic_settings = { metrics = { marketplace_partner_resource_id = "/providers/vendor/type/partner" } }
    ignore_body_changes = {
      network_load_balancers         = ["properties.probes"]
      authorization_locks            = ["properties.notes"]
      authorization_role_assignments = ["properties.description"]
      insights_diagnostic_settings   = ["properties.logs"]
    }
  }
  assert {
    condition     = var.ignore_body_changes.network_load_balancers == tolist(["properties.probes"])
    error_message = "The write-only interface must accept body-relative consumer paths; static wiring is checked separately, not read from state."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_null_controls_and_tags" {
  command = apply
  variables {
    tags                = null
    lock                = null
    retry               = null
    timeouts            = null
    resource_types      = null
    ignore_body_changes = null
  }
  assert {
    condition     = var.tags == null && azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && azapi_resource.this.type == "Microsoft.Network/loadBalancers@2025-01-01" && length(azapi_resource.lock) == 0 && length(time_sleep.lock_removal) == 0
    error_message = "Null tag input stays unspecified (provider tags are computed); retry/timeouts remain absent and non-null control objects substitute defaults."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "empty_maps_remove_interfaces_and_tags" {
  command = apply
  variables {
    tags                = {}
    diagnostic_settings = {}
    role_assignments    = {}
    lock                = null
    ignore_body_changes = { network_load_balancers = [], authorization_locks = [], authorization_role_assignments = [], insights_diagnostic_settings = [] }
  }
  assert {
    condition     = length(azapi_resource.this.tags) == 0 && length(azapi_resource.diagnostic_settings) == 0 && length(azapi_resource.role_assignments) == 0 && length(azapi_resource.lock) == 0 && length(time_sleep.lock_removal) == 0
    error_message = "Explicit empty interface maps remove Terraform instances, not just their optional properties; empty tags are not null."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_diagnostic_destination_type" {
  command = plan
  variables {
    diagnostic_settings = { bad = { marketplace_partner_resource_id = "/providers/vendor/type/partner", log_analytics_destination_type = "invalid" } }
  }
  expect_failures = [var.diagnostic_settings]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_diagnostic_log_neither_category_nor_group" {
  command = plan
  variables {
    diagnostic_settings = { bad = { marketplace_partner_resource_id = "/providers/vendor/type/partner", logs = [{}] } }
  }
  expect_failures = [var.diagnostic_settings]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_diagnostic_storage_id_type" {
  command = plan
  variables {
    diagnostic_settings = { bad = { storage_account_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/not-storage" } }
  }
  expect_failures = [var.diagnostic_settings]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_diagnostic_event_hub_rule_id" {
  command = plan
  variables {
    diagnostic_settings = { bad = { event_hub_authorization_rule_resource_id = "/invalid" } }
  }
  expect_failures = [var.diagnostic_settings]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
