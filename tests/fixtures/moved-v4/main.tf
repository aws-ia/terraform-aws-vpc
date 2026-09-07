terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

resource "aws_vpc" "main" {
  count                                = 1
  cidr_block                           = "10.42.0.0/16"
  assign_generated_ipv6_cidr_block     = true
  ipv6_cidr_block_network_border_group = "us-east-1"
}

resource "aws_subnet" "public" {
  for_each = {
    "us-east-1a" = "10.42.0.0/24"
  }

  vpc_id            = aws_vpc.main[0].id
  availability_zone = each.key
  cidr_block        = each.value
}

resource "aws_route_table" "public" {
  for_each = aws_subnet.public
  vpc_id   = aws_vpc.main[0].id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}

output "subnet_id" {
  value = aws_subnet.public["us-east-1a"].id
}

output "route_table_id" {
  value = aws_route_table.public["us-east-1a"].id
}

output "association_id" {
  value = aws_route_table_association.public["us-east-1a"].id
}

output "vpc_assign_generated_ipv6_cidr_block" {
  value = aws_vpc.main[0].assign_generated_ipv6_cidr_block
}
