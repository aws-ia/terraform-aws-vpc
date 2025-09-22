module "vpc_specific_azs" {
  source = "../.."

  name       = "specific-azs"
  cidr_block = var.cidr_block
  azs        = var.azs

  subnets = {
    private = {
      name_prefix = "vpc-specific-azs-private"
      netmask     = 18
    }
  }
}
