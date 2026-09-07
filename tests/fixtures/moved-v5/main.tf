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
  count      = 1
  cidr_block = "10.42.0.0/16"
}

resource "aws_subnet" "main" {
  for_each = {
    "public/us-east-1a" = {
      az   = "us-east-1a"
      cidr = "10.42.0.0/24"
    }
  }

  vpc_id            = aws_vpc.main[0].id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr
}

resource "aws_route_table" "main" {
  for_each = aws_subnet.main
  vpc_id   = aws_vpc.main[0].id
}

resource "aws_route_table_association" "main" {
  for_each       = aws_subnet.main
  subnet_id      = each.value.id
  route_table_id = aws_route_table.main[each.key].id
}

moved {
  from = aws_subnet.public["us-east-1a"]
  to   = aws_subnet.main["public/us-east-1a"]
}

moved {
  from = aws_route_table.public["us-east-1a"]
  to   = aws_route_table.main["public/us-east-1a"]
}

moved {
  from = aws_route_table_association.public["us-east-1a"]
  to   = aws_route_table_association.main["public/us-east-1a"]
}

output "subnet_id" {
  value = aws_subnet.main["public/us-east-1a"].id
}

output "route_table_id" {
  value = aws_route_table.main["public/us-east-1a"].id
}

output "association_id" {
  value = aws_route_table_association.main["public/us-east-1a"].id
}

output "subnet_keys" {
  value = keys(aws_subnet.main)
}
