module "vpc" {
  source = "../.."

  name           = "multi-az-vpc"
  vpc_cidr_block = "10.0.0.0/20"
  az_count       = 3

  subnets = {
    private = { netmask = 24 }
  }
}
