data "aws_availability_zones" "current" {}

module "vpc" {
  source = "../../.."
  #   source  = "aws-ia/vpc/aws"
  # version = ">= 2.0.0"

  name       = "primary-az-vpc"
  cidr_block = "10.0.0.0/16"
  az_count   = 2

  subnets = {
    public = {
      name_prefix               = "primary-vpc-public" # omit to prefix with "public"
      netmask                   = 24
      nat_gateway_configuration = "all_azs" # options: "single_az", "none"
    }
    private = {
      netmask                 = 24
      connect_to_public_natgw = true
    }
  }
}
