output "vpc" {
  description = "VPC Resource Information. Full output of aws_vpc."
  value       = local.vpc
}

output "subnets" {
  description = "Subnets grouped by type."
  value       = module.calculate_subnets.subnets_by_type
}

output "transit_gateway_attachment_id" {
  description = "Transit gateway attachment id."
  value       = try(aws_ec2_transit_gateway_vpc_attachment.tgw[0].id, null)
}
