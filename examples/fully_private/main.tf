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

provider "aws" {
  region  = var.region
  profile = var.profile
}

module "aws-ia_vpc" {
  source                        = "..\/..\/modules\/vpc"
  create_igw                    = var.create_igw
  create_nat_gateways_private_a = var.create_nat_gateways_private_a
  create_nat_gateways_private_b = var.create_nat_gateways_private_b
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
