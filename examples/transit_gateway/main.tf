resource "aws_ec2_transit_gateway" "example" {
  description = "example"
}

module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 1.0.0"

  name       = "tgw"
  cidr_block = "10.0.0.0/16"
  az_count   = 2

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "single_az"
      route_to_transit_gateway  = ["10.0.0.0/8"]
    }

    private = {
      netmask                  = 24
      route_to_nat             = true
      route_to_transit_gateway = ["10.0.0.0/8"]
    }

    transit_gateway = {
      netmask                                         = 28
      transit_gateway_id                              = aws_ec2_transit_gateway.example.id
      route_to_nat                                    = false
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
      transit_gateway_appliance_mode_support          = "enable"
      transit_gateway_dns_support                     = "disable"
    }
  }
}
