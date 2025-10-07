
# ---------- AMAZON VPC IPAM ----------
module "ipam" {
  source  = "aws-ia/ipam/aws"
  version = ">= 2.0.0"

  top_cidr = ["172.0.0.0/8"]

  pool_configurations = {
    (var.aws_region) = {
      description = "${var.aws_region} top level pool"
      cidr        = ["172.2.0.0/16"]
      locale      = var.aws_region
    }
  }
}

# ---------- AMAZON VPC ----------
module "vpc" {
  source = "../.."

  name     = "ipam-example-vpc"
  az_count = 3

  vpc_ipv4_ipam_pool_id   = module.ipam.pools_level_1.eu-west-1.id
  vpc_ipv4_netmask_length = 26

  subnets = {
    private = { netmask = 28 }
  }
}
