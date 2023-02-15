module "vpc" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 3.0.2"
  source = "../.."

  name     = "ipam-vpc"
  az_count = 3

  vpc_ipv4_ipam_pool_id   = module.ipam_base_for_example_only.pool_id
  vpc_ipv4_netmask_length = 26

  subnets = {
    private = {
      netmask                 = 28
      connect_to_public_natgw = false
    }
  }
}

#####################################
# For example purposes ONLY!
# Example of a simple IPAM deployment
#####################################

module "ipam_base_for_example_only" {
  source = "../../test/hcl_fixtures/ipam_base"
}
