output "subnets" {
  description = "Map of subnet types with key/value az = cidr."
  value       = module.vpc.subnets
}
