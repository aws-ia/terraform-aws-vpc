# VPC
output "vpc_cidr" {
  description = "VPC_CIDR "
  value       = module.aws-ia_vpc.vpc_cidr
}
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.aws-ia_vpc.vpc_id
}
output "NAT1EIP" {
  description = "NAT 1 IP address"
  value       = module.aws-ia_vpc.NAT1EIP
}

output "NAT2EIP" {
  description = " NAT 2 IP address"
  value       = module.aws-ia_vpc.NAT2EIP
}

output "NAT3EIP" {
  description = " NAT 3 IP address"
  value       = module.aws-ia_vpc.NAT3EIP
}

output "NAT4EIP" {
  description = " NAT 4 IP address"
  value       = module.aws-ia_vpc.NAT4EIP
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

output "PrivateSubnet1ACIDR" {
  description = " Private subnet 1A CIDR in Availability Zone 1"
  value       = module.aws-ia_vpc.PrivateSubnet1ACIDR
}

output "PrivateSubnet1AID" {
  description = " Private subnet 1A ID in Availability Zone 1"
  value       = module.aws-ia_vpc.PrivateSubnet1AID
}

output "PrivateSubnet1BCIDR" {
  description = " Private subnet 1B CIDR in Availability Zone 1"
  value       = module.aws-ia_vpc.PrivateSubnet1BCIDR
}

output "PrivateSubnet1BID" {
  description = " Private subnet 1B ID in Availability Zone 1"
  value       = module.aws-ia_vpc.PrivateSubnet1BID
}

output "PrivateSubnet2ACIDR" {
  description = " Private subnet 2A CIDR in Availability Zone 2"
  value       = module.aws-ia_vpc.PrivateSubnet2ACIDR
}

output "PrivateSubnet2AID" {
  description = " Private subnet 2A ID in Availability Zone 2"
  value       = module.aws-ia_vpc.PrivateSubnet2AID
}

output "PrivateSubnet2BCIDR" {
  description = " Private subnet 2B CIDR in Availability Zone 2"
  value       = module.aws-ia_vpc.PrivateSubnet2BCIDR
}

output "PrivateSubnet2BID" {
  description = " Private subnet 2B ID in Availability Zone 2"
  value       = module.aws-ia_vpc.PrivateSubnet2BID
}

output "PrivateSubnet3ACIDR" {
  description = " Private subnet 3A CIDR in Availability Zone 3"
  value       = module.aws-ia_vpc.PrivateSubnet3ACIDR
}

output "PrivateSubnet3AID" {
  description = " Private subnet 3A ID in Availability Zone 3"
  value       = module.aws-ia_vpc.PrivateSubnet3AID
}

output "PrivateSubnet3BCIDR" {
  description = " Private subnet 3B CIDR in Availability Zone 3"
  value       = module.aws-ia_vpc.PrivateSubnet3BCIDR
}

output "PrivateSubnet3BID" {
  description = " Private subnet 3B ID in Availability Zone 3"
  value       = module.aws-ia_vpc.PrivateSubnet3BID
}

output "PrivateSubnet4ACIDR" {
  description = " Private subnet 4A CIDR in Availability Zone 4"
  value       = module.aws-ia_vpc.PrivateSubnet4ACIDR
}

output "PrivateSubnet4AID" {
  description = " Private subnet 4A ID in Availability Zone 4"
  value       = module.aws-ia_vpc.PrivateSubnet4AID
}

output "PrivateSubnet4BCIDR" {
  description = " Private subnet 4B CIDR in Availability Zone 4"
  value       = module.aws-ia_vpc.PrivateSubnet4BCIDR
}

output "PrivateSubnet4BID" {
  description = " Private subnet 4B ID in Availability Zone 4"
  value       = module.aws-ia_vpc.PrivateSubnet4BID
}

output "PublicSubnet1CIDR" {
  description = " Public subnet 1 CIDR in Availability Zone 1"
  value       = module.aws-ia_vpc.PublicSubnet1CIDR
}

output "PublicSubnet1ID" {
  description = " Public subnet 1 ID in Availability Zone 1"
  value       = module.aws-ia_vpc.PublicSubnet1ID
}

output "PublicSubnet2CIDR" {
  description = " Public subnet 2 CIDR in Availability Zone 2"
  value       = module.aws-ia_vpc.PublicSubnet2CIDR
}

output "PublicSubnet2ID" {
  description = " Public subnet 2 ID in Availability Zone 2"
  value       = module.aws-ia_vpc.PublicSubnet2ID
}

output "PublicSubnet3CIDR" {
  description = " Public subnet 3 CIDR in Availability Zone 3"
  value       = module.aws-ia_vpc.PublicSubnet3CIDR
}

output "PublicSubnet3ID" {
  description = " Public subnet 3 ID in Availability Zone 3"
  value       = module.aws-ia_vpc.PublicSubnet3ID
}

output "PublicSubnet4CIDR" {
  description = " Public subnet 4 CIDR in Availability Zone 4"
  value       = module.aws-ia_vpc.PublicSubnet4CIDR
}

output "PublicSubnet4ID" {
  description = " Public subnet 4 ID in Availability Zone 4"
  value       = module.aws-ia_vpc.PublicSubnet4ID
}

output "S3VPCEndpoint" {
  description = " S3 VPC Endpoint"
  value       = module.aws-ia_vpc.S3VPCEndpoint
}

output "PrivateSubnet1ARouteTable" {
  description = " Private subnet 1A route table"
  value       = module.aws-ia_vpc.PrivateSubnet1ARouteTable
}

output "PrivateSubnet1BRouteTable" {
  description = " Private subnet 1B route table"
  value       = module.aws-ia_vpc.PrivateSubnet1BRouteTable
}

output "PrivateSubnet2ARouteTable" {
  description = " Private subnet 2A route table"
  value       = module.aws-ia_vpc.PrivateSubnet2ARouteTable
}

output "PrivateSubnet2BRouteTable" {
  description = " Private subnet 2B route table"
  value       = module.aws-ia_vpc.PrivateSubnet2BRouteTable
}

output "PrivateSubnet3ARouteTable" {
  description = " Private subnet 3A route table"
  value       = module.aws-ia_vpc.PrivateSubnet3ARouteTable
}

output "PrivateSubnet3BRouteTable" {
  description = " Private subnet 3B route table"
  value       = module.aws-ia_vpc.PrivateSubnet3BRouteTable
}

output "PrivateSubnet4ARouteTable" {
  description = " Private subnet 4A route table"
  value       = module.aws-ia_vpc.PrivateSubnet4ARouteTable
}

output "PrivateSubnet4BRouteTable" {
  description = " Private subnet 4B route table"
  value       = module.aws-ia_vpc.PrivateSubnet4BRouteTable
}

output "PublicSubnetRouteTable" {
  description = " Public subnet route table"
  value       = module.aws-ia_vpc.PublicSubnetRouteTable
}
