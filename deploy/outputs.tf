# VPC
output "vpc_cidr" {
  description = "VPC_CIDR "
  value       = module.aws-ia_vpc.vpc_cidr
}
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.aws-ia_vpc.vpc_id
}
output "nat_eip_1" {
  description = "NAT 1 IP address"
  value       = module.aws-ia_vpc.nat_eip_1
}

output "nat_eip_2" {
  description = " NAT 2 IP address"
  value       = module.aws-ia_vpc.nat_eip_2
}

output "nat_eip_3" {
  description = " NAT 3 IP address"
  value       = module.aws-ia_vpc.nat_eip_3
}

output "nat_eip_4" {
  description = " NAT 4 IP address"
  value       = module.aws-ia_vpc.nat_eip_4
}

output "private_subnet_route_tables" {
  description = "Private subnet route tables"
  value       = module.aws-ia_vpc.private_subnet_route_tables
}

output "private_subnets" {
  description = "Private subnet ids"
  value       = module.aws-ia_vpc.private_subnets
}

output "availability_zones" {
  description = "all availability zone names used by subnets in this vpc"
  value       = module.aws-ia_vpc.availability_zones
}

output "private_subnet_1a_cidr" {
  description = " Private subnet 1A CIDR in Availability Zone 1"
  value       = module.aws-ia_vpc.private_subnet_1a_cidr
}

output "private_subnet_1a_id" {
  description = " Private subnet 1A ID in Availability Zone 1"
  value       = module.aws-ia_vpc.private_subnet_1a_id
}

output "private_subnet_1b_cidr" {
  description = " Private subnet 1B CIDR in Availability Zone 1"
  value       = module.aws-ia_vpc.private_subnet_1b_cidr
}

output "private_subnet_1b_id" {
  description = " Private subnet 1B ID in Availability Zone 1"
  value       = module.aws-ia_vpc.private_subnet_1b_id
}

output "private_subnet_2a_cidr" {
  description = " Private subnet 2A CIDR in Availability Zone 2"
  value       = module.aws-ia_vpc.private_subnet_2a_cidr
}

output "private_subnet_2a_id" {
  description = " Private subnet 2A ID in Availability Zone 2"
  value       = module.aws-ia_vpc.private_subnet_2a_id
}

output "private_subnet_2b_cidr" {
  description = " Private subnet 2B CIDR in Availability Zone 2"
  value       = module.aws-ia_vpc.private_subnet_2b_cidr
}

output "private_subnet_2b_id" {
  description = " Private subnet 2B ID in Availability Zone 2"
  value       = module.aws-ia_vpc.private_subnet_2b_id
}

output "private_subnet_3a_cidr" {
  description = " Private subnet 3A CIDR in Availability Zone 3"
  value       = module.aws-ia_vpc.private_subnet_3a_cidr
}

output "private_subnet_3a_id" {
  description = " Private subnet 3A ID in Availability Zone 3"
  value       = module.aws-ia_vpc.private_subnet_3a_id
}

output "private_subnet_3b_cidr" {
  description = " Private subnet 3B CIDR in Availability Zone 3"
  value       = module.aws-ia_vpc.private_subnet_3b_cidr
}

output "private_subnet_3b_id" {
  description = " Private subnet 3B ID in Availability Zone 3"
  value       = module.aws-ia_vpc.private_subnet_3b_id
}

output "private_subnet_4a_cidr" {
  description = " Private subnet 4A CIDR in Availability Zone 4"
  value       = module.aws-ia_vpc.private_subnet_4a_cidr
}

output "private_subnet_4a_id" {
  description = " Private subnet 4A ID in Availability Zone 4"
  value       = module.aws-ia_vpc.private_subnet_4a_id
}

output "private_subnet_4b_cidr" {
  description = " Private subnet 4B CIDR in Availability Zone 4"
  value       = module.aws-ia_vpc.private_subnet_4b_cidr
}

output "private_subnet_4b_id" {
  description = " Private subnet 4B ID in Availability Zone 4"
  value       = module.aws-ia_vpc.private_subnet_4b_id
}

output "public_subnet_1_cidr" {
  description = " Public subnet 1 CIDR in Availability Zone 1"
  value       = module.aws-ia_vpc.public_subnet_1_cidr
}

output "public_subnet_1_id" {
  description = " Public subnet 1 ID in Availability Zone 1"
  value       = module.aws-ia_vpc.public_subnet_1_id
}

output "public_subnet_2_cidr" {
  description = " Public subnet 2 CIDR in Availability Zone 2"
  value       = module.aws-ia_vpc.public_subnet_2_cidr
}

output "public_subnet_2_id" {
  description = " Public subnet 2 ID in Availability Zone 2"
  value       = module.aws-ia_vpc.public_subnet_2_id
}

output "public_subnet_3_cidr" {
  description = " Public subnet 3 CIDR in Availability Zone 3"
  value       = module.aws-ia_vpc.public_subnet_3_cidr
}

output "public_subnet_3_id" {
  description = " Public subnet 3 ID in Availability Zone 3"
  value       = module.aws-ia_vpc.public_subnet_3_id
}

output "public_subnet_4_cidr" {
  description = " Public subnet 4 CIDR in Availability Zone 4"
  value       = module.aws-ia_vpc.public_subnet_4_cidr
}

output "public_subnet_4_id" {
  description = " Public subnet 4 ID in Availability Zone 4"
  value       = module.aws-ia_vpc.public_subnet_4_id
}

output "s3_vpc_endpoint" {
  description = " S3 VPC Endpoint"
  value       = module.aws-ia_vpc.s3_vpc_endpoint
}

output "private_subnet_1a_route_table" {
  description = " Private subnet 1A route table"
  value       = module.aws-ia_vpc.private_subnet_1a_route_table
}

output "private_subnet_1b_route_table" {
  description = " Private subnet 1B route table"
  value       = module.aws-ia_vpc.private_subnet_1b_route_table
}

output "private_subnet_2a_route_table" {
  description = " Private subnet 2A route table"
  value       = module.aws-ia_vpc.private_subnet_2a_route_table
}

output "private_subnet_2b_route_table" {
  description = " Private subnet 2B route table"
  value       = module.aws-ia_vpc.private_subnet_2b_route_table
}

output "private_subnet_3a_route_table" {
  description = " Private subnet 3A route table"
  value       = module.aws-ia_vpc.private_subnet_3a_route_table
}

output "private_subnet_3b_route_table" {
  description = " Private subnet 3B route table"
  value       = module.aws-ia_vpc.private_subnet_3b_route_table
}

output "private_subnet_4a_route_table" {
  description = " Private subnet 4A route table"
  value       = module.aws-ia_vpc.private_subnet_4a_route_table
}

output "private_subnet_4b_route_table" {
  description = " Private subnet 4B route table"
  value       = module.aws-ia_vpc.private_subnet_4b_route_table
}

output "public_subnet_route_table" {
  description = " Public subnet route table"
  value       = module.aws-ia_vpc.public_subnet_route_table
}
