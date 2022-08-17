data "aws_region" "current" {}

module "secondary" {
  source  = "aws-ia/vpc/aws"
  version = ">= 2.0.0"

  name       = "secondary-cidr"
  az_count   = 2
  cidr_block = "10.2.0.0/16"

  vpc_secondary_cidr = true
  vpc_id             = var.vpc_id

  # If referencing another instantiation of this module, you can use the output nat_gateway_attributes_by_az, example:
  # vpc_secondary_cidr_natgw = module.vpc.nat_gateway_attributes_by_az
  vpc_secondary_cidr_natgw = {
    "${data.aws_region.current.name}a" : {
      id : var.natgw_id_1
    }
    "${data.aws_region.current.name}b" : {
      id : var.natgw_id_2
    }
  }
  subnets = {
    private = {
      name_prefix             = "secondary-private-natgw-connected"
      netmask                 = 18
      connect_to_public_natgw = true
    }
  }
}
