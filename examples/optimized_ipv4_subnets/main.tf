data "aws_availability_zones" "current" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = "~> 4.4"

  name                        = "sorted-subnets"
  cidr_block                  = var.vpc_cidr
  az_count                    = 3
  optimize_subnet_cidr_ranges = true

  subnets = {
    private = {
      netmask = 24
    }
    database = {
      netmask = 27
    }
    public = {
      netmask                   = 28
      nat_gateway_configuration = "single_az"
    }
    infrastructure = {
      netmask = 28
    }
  }
}
