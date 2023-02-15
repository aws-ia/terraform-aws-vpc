data "aws_region" "current" {}

module "secondary" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 3.0.2"
  source = "../.."

  name       = "secondary-cidr"
  az_count   = 2
  cidr_block = "10.2.0.0/16"

  vpc_secondary_cidr = true
  vpc_id             = var.vpc_id

  vpc_secondary_cidr_natgw = var.natgw_id_per_az

  # If referencing another instantiation of this module, you can use the output natgw_id_per_az, example:
  # vpc_secondary_cidr_natgw = module.vpc.natgw_id_per_az

  # underly structure is:
  # {
  #   az : {
  #     id : "nat-asdf"
  #   }
  # }
  # but preferably you should just pass the module output natgw_id_per_az

  subnets = {
    private = {
      name_prefix             = "secondary-private-natgw-connected"
      netmask                 = 18
      connect_to_public_natgw = true
    }
  }
}
