variable "region" {
  description = "AWS region to create VPC in"
  type        = string
}

variable "profile" {
  description = "AWS CLI profile to use when calling AWS API's"
  type        = string
}

variable "create_igw" {
  description = "If set to false no IGW will be created for the public subnets. Setting this to false will also disable NAT gateways on private subnets, as NAT gateways require IGW in public subnets"
  type        = bool
  default     = false
}

variable "create_nat_gateways_private_b" {
  description = "If set to false no NAT gateways will be created for the private_b subnets"
  type        = bool
  default     = false
}

variable "create_nat_gateways_private_a" {
  description = "If set to false no NAT gateways will be created for the private_a subnets"
  type        = bool
  default     = false
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
  private_subnet_b_cidrs        = ["10.0.112.0/20", "10.0.128.0/20", "10.0.144.0/20"]
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
