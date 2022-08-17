# To test this example, uncomment the module blocks for "vpc" and "ipam_base_for_example_only"

module "secondary" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 2.0.0"
  source = "../.."

  name       = "secondary-cidr"
  cidr_block = "10.2.0.0/16"

  vpc_secondary_cidr = true
  vpc_id             = module.vpc.vpc_attributes.id

  vpc_secondary_cidr_natgw = module.vpc.nat_gateway_attributes_by_az
  az_count                 = 2

  subnets = {
    private = {
      name_prefix             = "secondary-private-natgw-connected"
      netmask                 = 18
      connect_to_public_natgw = true
    }
  }
}

module "vpc" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 2.0.0"
  source = "../.."

  name       = "primary-az-vpc"
  cidr_block = "10.0.0.0/16"
  az_count   = 3

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
