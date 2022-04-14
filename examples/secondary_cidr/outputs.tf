output "secondary_subnets" {
  description = "Map of subnet types with key/value az = cidr."
  value       = module.secondary.subnets
}
