output "public_subnets" {
  description = "Map of subnet types with key/value az = cidr."
  value       = module.vpc.private_subnet_cidrs_by_az
}
