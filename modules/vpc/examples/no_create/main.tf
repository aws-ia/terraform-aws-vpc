variable "region" {
  description = "AWS region to create VPC in"
  type        = string
}

variable "profile" {
  description = "AWS CLI profile to use when calling AWS API's"
  type        = string
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

module "aws-ia_vpc" {
  source     = "../../"
  create_vpc = false
}
