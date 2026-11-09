output "global_load_balancer_resource_id" {
  description = "Global load balancer ARM ID."
  value       = module.global.resource_id
}

output "regional_frontend_resource_ids" {
  description = "Regional public frontend IDs used as actual Global pool members."
  value       = { for key, region in module.regional : key => region.frontend_ip_configuration_resource_ids["public"] }
}

output "regional_backend_pool_resource_ids" {
  description = "Separate IP and native NIC pool IDs for each region."
  value       = { for key, region in module.regional : key => region.backend_address_pool_resource_ids }
}
