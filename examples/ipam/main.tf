module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 2.0.0"

  name     = "ipam-vpc"
  az_count = 3

  vpc_ipv4_ipam_pool_id   = module.ipam_base_for_example_only.pool_id # var.ipam_pool_id
  vpc_ipv4_netmask_length = 20

  subnets = {
    public = {
      netmask = 24

      nat_gateway_configuration = "all_azs"
    }
    private = {
      netmask      = 24
      route_to_nat = true
    }
  }
}

#####################################
# Example of a simple IPAM deployment
# terraform apply -target=module.ipam_base_for_example_only
#####################################

# module "ipam_base_for_example_only" {
#   source = "../../test/hcl_fixtures/ipam_base"
# }
