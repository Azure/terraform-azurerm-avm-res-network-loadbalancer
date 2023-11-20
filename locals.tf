# TODO: insert locals here.

locals {

  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

}

# Role assignments for public ip address
locals {
  pip_role_assignments = { for ra in flatten([
    for fe_k, fe_v in var.frontend_ip_configurations : [
      for rk, rv in fe_v.role_assignments : {
        frontend_key    = fe_k
        ra_key          = rk
        role_assignment = rv
      }
    ]
  ]) : "${ra.frontend_key}-${ra.ra_key}" => ra }
}
