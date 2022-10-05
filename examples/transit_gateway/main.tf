data "aws_availability_zones" "current" {}

module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 3.0.0"

  name               = "tgw"
  cidr_block         = "10.0.0.0/16"
  az_count           = 2
  transit_gateway_id = module.tgw_base_for_example_only.tgw_id
  transit_gateway_routes = {
    public              = "10.0.0.0/8"
    private_with_egress = "192.168.0.0/16"
  }

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "single_az"
    }

    private_with_egress = {
      netmask                 = 24
      connect_to_public_natgw = true
    }

    truly_private = {
      netmask = 24
    }

    transit_gateway = {
      netmask                                         = 28
      connect_to_public_natgw                         = true
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
      transit_gateway_appliance_mode_support          = "enable"
      transit_gateway_dns_support                     = "disable"

      tags = {
        subnet_type = "tgw"
      }
    }
  }
}

#####################################
# Example of a tgw deployment
#####################################

module "tgw_base_for_example_only" {
  source = "../../test/hcl_fixtures/transit_gateway_base"
}
