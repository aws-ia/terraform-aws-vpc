variable "region" {
  type    = string
  default = "us-east-1"
}

variable "profile" {
  type    = string
  default = null
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

provider "awscc" {
  region  = var.region
  profile = var.profile
}

module "aws-ia_vpc" {
  source = "../../"
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
