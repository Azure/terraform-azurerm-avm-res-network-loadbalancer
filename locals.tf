locals {
  pip_diagnostic_settings = { for ds in flatten([
    for fe_k, fe_v in var.frontend_ip_configurations : [
      for dk, dv in fe_v.diagnostic_settings : {
        frontend_key       = fe_k
        ds_key             = dk
        diagnostic_setting = dv
      }
    ]
  ]) : "${ds.frontend_key}-${ds.ds_key}" => ds }
  pip_role_assignments = { for ra in flatten([
    for fe_k, fe_v in var.frontend_ip_configurations : [
      for rk, rv in fe_v.role_assignments : {
        frontend_key    = fe_k
        ra_key          = rk
        role_assignment = rv
      }
    ]
  ]) : "${ra.frontend_key}-${ra.ra_key}" => ra }
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}
