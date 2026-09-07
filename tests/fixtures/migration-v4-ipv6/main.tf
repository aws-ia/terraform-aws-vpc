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
  count = 1

  cidr_block                       = "10.44.0.0/16"
  assign_generated_ipv6_cidr_block = true
}

output "vpc_id" {
  value = aws_vpc.main[0].id
}

output "ipv6_association_id" {
  value = aws_vpc.main[0].ipv6_association_id
}

output "assign_generated_ipv6_cidr_block" {
  value = aws_vpc.main[0].assign_generated_ipv6_cidr_block
}
