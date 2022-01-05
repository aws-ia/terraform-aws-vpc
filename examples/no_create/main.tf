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

module "aws-ia_vpc" {
  source     = "../../"
  create_vpc = false
}
