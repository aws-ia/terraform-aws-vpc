module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 1.0.0"

  name           = "multi-az-vpc"
  vpc_cidr_block = "10.0.0.0/20"
  az_count       = 3

  subnets = {
    private = { netmask = 24 }
  }
}
