module "vpc" {
  source = "../.."

  name           = "multi-az-vpc"
  vpc_cidr_block = "10.0.0.0/20"
  az_count       = 3

  subnets = {
    public = {
      name_prefix               = "my-public" # omit to prefix with "public"
      netmask                   = 24
      nat_gateway_configuration = "all_azs" # options: "single_az", "none"
    }
  }


}
