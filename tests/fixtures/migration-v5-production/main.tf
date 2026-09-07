terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}

module "vpc" {
  source = "../../.."

  vpc                = { name = "production-ipv6-handoff" }
  addressing         = { primary = { cidr_block = "10.44.0.0/16" }, secondary = { v4-ipv6 = { ipv6 = { amazon_assigned = true } } } }
  availability_zones = { names = ["us-east-1a"] }
}

moved {
  from = aws_vpc.main[0]
  to   = module.vpc.aws_vpc.main[0]
}

import {
  to = module.vpc.aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]
  id = "vpc-cidr-assoc-0123456789abcdef0"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_assign_generated_ipv6_cidr_block" {
  value = module.vpc.resources.vpc.created[0].assign_generated_ipv6_cidr_block
}

output "ipv6_association_id" {
  value = module.vpc.resources.secondary_ipv6_cidr_associations["v4-ipv6"].id
}
