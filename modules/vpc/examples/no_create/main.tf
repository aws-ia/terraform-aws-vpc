variable "region" {
  type = string
}

variable "profile" {
  type = string
}

provider "aws" {
  region = var.region
  profile = var.profile
}

module "aws-ia_vpc" {
  source                    = "../../"
  create_vpc = false
}

output "public_subnet_ids" {
  value = module.aws-ia_vpc.public_subnet_ids
}

output "private_subnet_a_ids" {
  value = module.aws-ia_vpc.private_subnet_a_ids
}

output "private_subnet_b_ids" {
  value = module.aws-ia_vpc.private_subnet_b_ids
}
