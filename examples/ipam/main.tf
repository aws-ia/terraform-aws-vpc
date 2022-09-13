module "vpc" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 2.0.0"
  # source = "github.com/vivgoyal-aws/terraform-aws-vpc"

  source = "../.."

  name     = "ipam-vpc"
  az_count = 3

  vpc_ipv4_ipam_pool_id = "ipam-pool-079f76df39be519c9" # module.ipam_base_for_example_only.pool_id #var.ipam_pool_id #
  # vpc_ipv4_netmask_length = 26
  cidr_block = "172.2.0.192/26"

  subnets = {
    private = {
      cidrs = ["172.2.0.192/28", "172.2.0.208/28", "172.2.0.224/28"]
      # netmask                 = 28
      connect_to_public_natgw = false
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
