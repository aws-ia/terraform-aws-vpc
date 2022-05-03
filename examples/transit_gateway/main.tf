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
      netmask                  = 24
      route_to_transit_gateway = ["0.0.0.0/0"]
    }

    private = {
      netmask                  = 24
      route_to_nat             = true
      route_to_transit_gateway = ["0.0.0.0/0"]
    }

    transit_gateway = {
      netmask                                         = 24
      transit_gateway_id                              = aws_ec2_transit_gateway.example.id
      route_to_nat                                    = true # default false
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
    }
  }
}

