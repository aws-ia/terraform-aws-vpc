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
    transit_gateway = {
      netmask            = 24
      transit_gateway_id = aws_ec2_transit_gateway.example.id
    }
  }
}

