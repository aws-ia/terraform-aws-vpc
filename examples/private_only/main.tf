module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 1.0.0"

  name       = "multi-az-vpc"
  cidr_block = "10.0.0.0/20"
  az_count   = 1

  subnets = {
    private = { netmask = 24 }
  }
}
