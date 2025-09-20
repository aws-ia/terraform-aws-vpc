module "vpc" {
  source = "../.."

  name     = "ipam-vpc"
  az_count = 3

  vpc_ipv4_ipam_pool_id   = data.aws_vpc_ipam_pool.test.id
  vpc_ipv4_netmask_length = 26

  subnets = {
    private = {
      netmask                 = 28
      connect_to_public_natgw = false
    }
  }
}

data "aws_vpc_ipam_pool" "test" {
  filter {
    name   = "description"
    values = ["*top level pool*"]
  }

  filter {
    name   = "address-family"
    values = ["ipv4"]
  }
}
