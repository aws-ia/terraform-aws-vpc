# VPC
output "vpc_cidr" {
  description = "VPC_CIDR "
  #value       = aws_vpc.main[count.index].cidr_block
  value = concat(aws_vpc.main.*.cidr_block, [""])[0]
}
output "vpc_id" {
  description = "The ID of the VPC"
  #value       = aws_vpc.main[count.index].id
  value = concat(aws_vpc.main.*.id, [""])[0]
}
output "private_subnets_a" {
  description = "List of IDs of privateA subnets"
  value       = aws_subnet.private_A.*.id
}
output "private_subnets_b" {
  description = "List of IDs of privateB subnets"
  value       = aws_subnet.private_B.*.id
}
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = flatten([compact(aws_subnet.private_A.*.id), compact(aws_subnet.private_B.*.id)])
}
output "private_subnet_route_tables" {
  description = "List of IDs of private subnets"
  value       = flatten([aws_route_table.private_A.*.id, aws_route_table.private_B.*.id])
}
output "availability_zones" {
  description = "List of availability zones names for subnets in this vpc"
  value = compact(distinct(flatten([
    aws_subnet.private_A.*.availability_zone,
    aws_subnet.private_B.*.availability_zone,
    aws_subnet.public.*.availability_zone
  ])))
}
output "public_subnets" {
  description = "List of IDs of privateB subnets"
  value       = aws_subnet.public.*.id
}
output "nat_eip_1" {
  description = "NAT 1 IP address"
  value       = try(aws_eip.nat[0].public_ip, "")
}

output "nat_eip_2" {
  description = " NAT 2 IP address"
  value       = try(aws_eip.nat[1].public_ip, "")
}

output "nat_eip_3" {
  description = " NAT 3 IP address"
  value       = length(aws_eip.nat.*.public_ip) > 2 ? aws_eip.nat[2].public_ip : null
}

output "nat_eip_4" {
  description = " NAT 4 IP address"
  value       = length(aws_eip.nat.*.public_ip) > 3 ? aws_eip.nat[3].public_ip : null
}

output "private_subnet_1a_cidr" {
  description = " Private subnet 1A CIDR in Availability Zone 1"
  value       = try(aws_subnet.private_A[0].cidr_block, "")
}

output "private_subnet_1a_id" {
  description = " Private subnet 1A ID in Availability Zone 1"
  value       = try(aws_subnet.private_A[0].id, "")
}

output "private_subnet_1b_cidr" {
  description = " Private subnet 1B CIDR in Availability Zone 1"
  value       = try(aws_subnet.private_B[0].cidr_block, "")
}

output "private_subnet_1b_id" {
  description = " Private subnet 1B ID in Availability Zone 1"
  value       = try(aws_subnet.private_B[0].id, "")
}

output "private_subnet_2a_cidr" {
  description = " Private subnet 2A CIDR in Availability Zone 2"
  value       = try(aws_subnet.private_A[1].cidr_block, "")
}

output "private_subnet_2a_id" {
  description = " Private subnet 2A ID in Availability Zone 2"
  value       = try(aws_subnet.private_A[1].id, "")
}

output "private_subnet_2b_cidr" {
  description = " Private subnet 2B CIDR in Availability Zone 2"
  value       = try(aws_subnet.private_B[1].cidr_block, "")
}

output "private_subnet_2b_id" {
  description = " Private subnet 2B ID in Availability Zone 2"
  value       = try(aws_subnet.private_B[1].id, "")
}

output "private_subnet_3a_cidr" {
  description = " Private subnet 3A CIDR in Availability Zone 3"
  value       = length(aws_subnet.private_A.*.cidr_block) > 2 ? aws_subnet.private_A[2].cidr_block : null
}

output "private_subnet_3a_id" {
  description = " Private subnet 3A ID in Availability Zone 3"
  value       = length(aws_subnet.private_A.*.id) > 2 ? aws_subnet.private_A[2].id : null
}

output "private_subnet_3b_cidr" {
  description = " Private subnet 3B CIDR in Availability Zone 3"
  value       = length(aws_subnet.private_B.*.cidr_block) > 2 ? aws_subnet.private_B[2].cidr_block : null
}

output "private_subnet_3b_id" {
  description = " Private subnet 3B ID in Availability Zone 3"
  value       = length(aws_subnet.private_B.*.id) > 2 ? aws_subnet.private_B[2].id : null
}

output "private_subnet_4a_cidr" {
  description = " Private subnet 4A CIDR in Availability Zone 4"
  value       = length(aws_subnet.private_A.*.cidr_block) > 3 ? aws_subnet.private_A[3].cidr_block : null
}

output "private_subnet_4a_id" {
  description = " Private subnet 4A ID in Availability Zone 4"
  value       = length(aws_subnet.private_A.*.id) > 3 ? aws_subnet.private_A[3].id : null
}

output "private_subnet_4b_cidr" {
  description = " Private subnet 4B CIDR in Availability Zone 4"
  value       = length(aws_subnet.private_B.*.cidr_block) > 3 ? aws_subnet.private_B[3].cidr_block : null
}

output "private_subnet_4b_id" {
  description = " Private subnet 4B ID in Availability Zone 4"
  value       = length(aws_subnet.private_B.*.id) > 3 ? aws_subnet.private_B[3].id : null
}

output "public_subnet_1_cidr" {
  description = " Public subnet 1 CIDR in Availability Zone 1"
  value       = try(aws_subnet.public[0].cidr_block, "")
}

output "public_subnet_1_id" {
  description = " Public subnet 1 ID in Availability Zone 1"
  value       = try(aws_subnet.public[0].id, "")
}

output "public_subnet_2_cidr" {
  description = " Public subnet 2 CIDR in Availability Zone 2"
  value       = try(aws_subnet.public[1].cidr_block, "")
}

output "public_subnet_2_id" {
  description = " Public subnet 2 ID in Availability Zone 2"
  value       = try(aws_subnet.public[1].id, "")
}

output "public_subnet_3_cidr" {
  description = " Public subnet 3 CIDR in Availability Zone 3"
  value       = length(aws_subnet.public.*.cidr_block) > 2 ? aws_subnet.public[2].cidr_block : null
}

output "public_subnet_3_id" {
  description = " Public subnet 3 ID in Availability Zone 3"
  value       = length(aws_subnet.public.*.id) > 2 ? aws_subnet.public[2].id : null
}

output "public_subnet_4_cidr" {
  description = " Public subnet 4 CIDR in Availability Zone 4"
  value       = length(aws_subnet.public.*.cidr_block) > 3 ? aws_subnet.public[3].cidr_block : null
}

output "public_subnet_4_id" {
  description = " Public subnet 4 ID in Availability Zone 4"
  value       = length(aws_subnet.public.*.id) > 3 ? aws_subnet.public[3].id : null
}

output "s3_vpc_endpoint" {
  description = " S3 VPC Endpoint"
  value       = aws_vpc_endpoint.s3.*.id
}

output "private_subnet_1a_route_table" {
  description = " Private subnet 1A route table"
  value       = try(aws_route_table.private_A[0].id, "")
}

output "private_subnet_1b_route_table" {
  description = " Private subnet 1B route table"
  value       = try(aws_route_table.private_B[0].id, "")
}

output "private_subnet_2a_route_table" {
  description = " Private subnet 2A route table"
  value       = try(aws_route_table.private_A[1].id, "")
}

output "private_subnet_2b_route_table" {
  description = " Private subnet 2B route table"
  value       = try(aws_route_table.private_B[1].id, "")
}

output "private_subnet_3a_route_table" {
  description = " Private subnet 3A route table"
  value       = length(aws_route_table.private_A.*.id) > 2 ? aws_route_table.private_A[2].id : null
}

output "private_subnet_3b_route_table" {
  description = " Private subnet 3B route table"
  value       = length(aws_route_table.private_B.*.id) > 2 ? aws_route_table.private_B[2].id : null
}

output "private_subnet_4a_route_table" {
  description = " Private subnet 4A route table"
  value       = length(aws_route_table.private_A.*.id) > 3 ? aws_route_table.private_A[3].id : null
}

output "private_subnet_4b_route_table" {
  description = " Private subnet 4B route table"
  value       = length(aws_route_table.private_B.*.id) > 3 ? aws_route_table.private_B[3].id : null
}

output "public_subnet_route_table" {
  description = " Public subnet route table"
  value       = aws_route_table.public.*.id
}
