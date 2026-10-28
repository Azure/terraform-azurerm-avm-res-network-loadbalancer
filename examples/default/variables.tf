variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Enable AVM telemetry for this example."
}

variable "location" {
  type        = string
  default     = "eastus2"
  description = "Region supporting zone-redundant Standard load balancers."
}
