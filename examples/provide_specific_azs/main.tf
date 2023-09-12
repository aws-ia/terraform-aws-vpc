module "vpc_specific_azs" {
  # source  = "aws-ia/vpc/aws"
  # version = ">= 4.3.1"
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
