output "vpc_id" {
  description = "VPC Information"
  value       = local.vpc
}

output "subnets" {
  description = "Subnets grouped by type."
  value       = module.calculate_subnets.subnets_by_type
}
