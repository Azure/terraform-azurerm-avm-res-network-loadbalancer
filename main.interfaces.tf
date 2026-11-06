data "azapi_resource_list" "role_definitions" {
  count = anytrue([for assignment in var.role_assignments : !strcontains(lower(assignment.role_definition_id_or_name), "/providers/microsoft.authorization/roledefinitions/")]) ? 1 : 0

  parent_id = var.parent_id
  type      = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  response_export_values = {
    results = "value[].{id: id, role_name: properties.roleName}"
  }
}

module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  location               = var.location
  diagnostic_settings_v2 = var.diagnostic_settings
  enable_telemetry       = var.enable_telemetry
  lock = var.lock == null ? null : {
    kind  = var.lock.kind
    name  = coalesce(var.lock.name, "lock-${var.name}")
    notes = coalesce(var.lock.notes, local.lock_notes[var.lock.kind])
  }
  role_assignment_definition_lookup_enabled = false
  role_assignments                          = local.resolved_role_assignments
}

resource "azapi_resource" "diagnostic_settings" {
  for_each = var.diagnostic_settings

  name                = coalesce(each.value.name, "diag-${var.name}")
  parent_id           = azapi_resource.this.id
  type                = var.resource_types.insights_diagnostic_settings
  body                = module.avm_interfaces.diagnostic_settings_azapi_v2[each.key].body
  ignore_body_changes = length(var.ignore_body_changes.insights_diagnostic_settings) > 0 ? var.ignore_body_changes.insights_diagnostic_settings : null
  # Utility v2 maps omitted/null/empty entries to null (unspecified). Azure
  # expands unspecified logs into disabled categories on GET. Omit nulls,
  # without ignoring configured category/group/enabled/destination values.
  ignore_null_property = true
  list_unique_id_property = {
    "properties.logs"    = "category,categoryGroup"
    "properties.metrics" = "category"
  }
  response_export_values = []
  retry                  = var.retry

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

resource "azapi_resource" "role_assignments" {
  for_each = var.role_assignments

  name                 = module.avm_interfaces.role_assignments_azapi[each.key].name
  parent_id            = azapi_resource.this.id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_interfaces.role_assignments_azapi[each.key].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_external_values = {
    principal_id                           = lower(each.value.principal_id)
    principal_type                         = local.resolved_role_assignments[each.key].principal_type
    role_definition_id_or_name             = lower(each.value.role_definition_id_or_name)
    description                            = each.value.description
    condition                              = each.value.condition
    condition_version                      = each.value.condition_version
    delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  }
  response_export_values = []
  retry                  = var.retry

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
    ignore_changes = [name]
    precondition {
      condition     = strcontains(lower(local.resolved_role_assignments[each.key].role_definition_id_or_name), "/providers/microsoft.authorization/roledefinitions/")
      error_message = "The role definition name could not be resolved at the resource group. Supply an assignable role name or resource ID."
    }
  }
}

resource "time_sleep" "lock_removal" {
  count = var.lock == null ? 0 : 1

  destroy_duration = "30s"
  triggers         = { resource_id = azapi_resource.this.id }

  depends_on = [
    azapi_resource.this,
    azapi_resource.diagnostic_settings,
    azapi_resource.role_assignments,
    azapi_update_resource.backend_members,
    azapi_resource_action.clear_backend_members,
  ]
}

resource "azapi_resource" "lock" {
  count = var.lock == null ? 0 : 1

  name                   = module.avm_interfaces.lock_azapi.name
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_locks
  body                   = module.avm_interfaces.lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  depends_on = [time_sleep.lock_removal]
}
