# To test this example, uncomment the module blocks for "vpc" and "ipam_base_for_example_only"

module "secondary" {
  source  = "aws-ia/vpc/aws"
  version = ">= 2.0.0"

  name = "secondary-cidr"

  vpc_secondary_cidr      = true
  vpc_id                  = module.vpc.vpc.id
  vpc_ipv4_ipam_pool_id   = module.ipam_base_for_example_only.pool_id
  vpc_ipv4_netmask_length = 20
  az_count                = 2

  subnets = {
    private = { netmask = 24 }
  }
}

# module "ipam_base_for_example_only" {
#   source = "../../test/hcl_fixtures/ipam_base"
# }

# module "vpc" {
#   source  = "aws-ia/vpc/aws"
#   version = ">= 1.0.0"

#   name       = "multi-az-vpc"
#   cidr_block = "10.0.0.0/16"
#   az_count   = 3

#   subnets = {
#     private = { netmask = 24 }
#   }
# }
