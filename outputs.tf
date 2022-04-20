output "vpc" {
  description = "VPC Resource Information. Full output of aws_vpc."
  value       = local.vpc
}

output "subnets" {
  description = "Map of subnets grouped by type with child map { az = cidr }"
  value       = module.calculate_subnets.subnets_by_type
}

output "transit_gateway_attachment_id" {
  description = "Transit gateway attachment id."
  value       = try(aws_ec2_transit_gateway_vpc_attachment.tgw[0].id, null)
}

output "private_subnet_attributes_by_az" {
  description = "Map of all private subnets containing their attributes."
  value       = try(aws_subnet.private, null)
}

output "public_subnet_attributes_by_az" {
  description = "Map of all public subnets containing their attributes."
  value       = try(aws_subnet.public, null)
}

output "tgw_subnet_attributes_by_az" {
  description = "Map of all transit gateway subnets containing their attributes."
  value       = try(aws_subnet.tgw, null)
}
