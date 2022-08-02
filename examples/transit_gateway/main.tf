resource "aws_ec2_managed_prefix_list" "example" {
  name           = "All VPC CIDR-s"
  address_family = "IPv4"
  max_entries    = 5

  entry {
    cidr        = "10.0.0.0/8"
    description = "Primary"
  }
}

module "vpc" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 1.0.0"
  source = "../.."

  name       = "tgw"
  cidr_block = "10.0.0.0/16"
  az_count   = 2

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "single_az"

      route_to_transit_gateway = true
      destination_route_to_tgw = aws_ec2_managed_prefix_list.example.id
    }

    private = {
      netmask                  = 24
      route_to_nat             = true
      destination_route_to_nat = "0.0.0.0/0"

      # route_to_transit_gateway = true
      # destination_route_to_tgw = aws_ec2_managed_prefix_list.example.id
    }

    # privatetwo = {
    #   netmask                  = 24
    #   route_to_nat             = true
    #   destination_route_to_nat = "1.1.1.0/20"

    #   route_to_transit_gateway = true
    #   destination_route_to_tgw = "10.0.0.0/8"

    # }

    transit_gateway = {
      name_prefix                                     = "tgw_test"
      netmask                                         = 28
      transit_gateway_id                              = module.tgw_base_for_example_only.tgw_id # var.tgw_id
      route_to_nat                                    = false
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
      transit_gateway_appliance_mode_support          = "enable"
      transit_gateway_dns_support                     = "disable"
    }
  }
}

#####################################
# Example of a tgw deployment
# terraform apply -target=module.tgw_base_for_example_only
#####################################

module "tgw_base_for_example_only" {
  source = "../../test/hcl_fixtures/transit_gateway_base"
}
