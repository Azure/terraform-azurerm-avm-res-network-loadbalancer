output "resource" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = module.loadbalancer.resource
}

output "resource_id" {
  description = "Outputs each Public IP Address resource in it's entirety"
  value       = module.loadbalancer.resource_id
}
