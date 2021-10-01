variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "create_igw" {
  type    = bool
  default = false
}

variable "create_nat_gateways_private_b" {
  type    = bool
  default = false
}

variable "create_nat_gateways_private_a" {
  type    = bool
  default = false
}

variable "enabled_interface_endpoints" {
  type    = list(string)
  default = ["s3", "sqs"]
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

module "aws-ia_vpc" {
  source                        = "../../"
  create_igw                    = var.create_igw
  create_nat_gateways_private_a = var.create_nat_gateways_private_a
  create_nat_gateways_private_b = var.create_nat_gateways_private_b
  enabled_interface_endpoints   = var.enabled_interface_endpoints
}

output "igw_id" {
  value = module.aws-ia_vpc.igw_id
}

output "nat_gw_ids" {
  value = module.aws-ia_vpc.nat_gw_ids
}

output "private_a_nat_routes" {
  value = module.aws-ia_vpc.private_a_nat_routes
}

output "private_b_nat_routes" {
  value = module.aws-ia_vpc.private_b_nat_routes
}

output "endpoints" {
  value = {
    s3 = {
      arn                 = module.aws-ia_vpc.interface_endpoints["s3"]["arn"]
      private_dns_enabled = module.aws-ia_vpc.interface_endpoints["s3"]["private_dns_enabled"]
    },
    sts = {
      arn                 = module.aws-ia_vpc.interface_endpoints["sqs"]["arn"]
      private_dns_enabled = module.aws-ia_vpc.interface_endpoints["sqs"]["private_dns_enabled"]
    }
  }
}

output "endpoint_sg_id" {
  value = module.aws-ia_vpc.vpc_endpoint_security_group_id
}
