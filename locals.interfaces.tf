locals {
  subscription_id = provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).subscription_id
  role_definition_ids_by_name = length(data.azapi_resource_list.role_definitions) == 0 ? {} : {
    for role in data.azapi_resource_list.role_definitions[0].output.results : lower(role.role_name) => role.id...
  }
  resolved_role_assignments = {
    for key, assignment in var.role_assignments : key => merge(assignment, {
      principal_type = assignment.principal_type == null && assignment.skip_service_principal_aad_check ? "ServicePrincipal" : assignment.principal_type
      role_definition_id_or_name = (
        !strcontains(lower(assignment.role_definition_id_or_name), "/providers/microsoft.authorization/roledefinitions/") ? try(local.role_definition_ids_by_name[lower(assignment.role_definition_id_or_name)][0], assignment.role_definition_id_or_name) :
        startswith(lower(assignment.role_definition_id_or_name), "/providers/") ? "/subscriptions/${local.subscription_id}${assignment.role_definition_id_or_name}" :
        assignment.role_definition_id_or_name
      )
    })
  }
  lock_notes = {
    CanNotDelete = "Cannot delete the resource or its child resources."
    ReadOnly     = "Cannot delete or modify the resource or its child resources."
  }
}
