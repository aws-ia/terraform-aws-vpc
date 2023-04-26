data "aws_availability_zones" "current" {}

module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 4.2.0"

  name       = "flowlogs"
  cidr_block = "10.0.0.0/20"
  az_count   = 2

  subnets = {
    public = {
      name_prefix               = "my-public" # omit to prefix with "public"
      netmask                   = 24
      nat_gateway_configuration = "all_azs" # options: "single_az", "none"
      tags = {
        subnet_type = "public"
      }
    }

    private = {
      # omitting name_prefix defaults value to "private"
      # name_prefix  = "private"
      netmask                 = 24
      connect_to_public_natgw = true
    }
  }

  vpc_flow_logs = var.vpc_flow_logs
}
