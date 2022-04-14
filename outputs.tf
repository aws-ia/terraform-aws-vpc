output "vpc" {
  description = "VPC Resource Information. Full output of aws_vpc."
  value       = local.vpc
}

output "subnets" {
  description = "Subnets grouped by type."
  value       = module.calculate_subnets.subnets_by_type
}
