data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

data "aws_vpc" "selected" {
  tags = {
    Name = "primary-az-vpc"
  }
}

data "aws_nat_gateway" "default" {
  vpc_id = data.aws_vpc.selected.id

  tags = {
    Name = "nat-primary-vpc-public-${data.aws_region.current.name}a"
  }
}

module "secondary" {
  source = "../.."

  name       = "secondary-cidr"
  create_vpc = false

  #   If the AZ calculation is done in the module when creating a secondary CIDR, it will not
  #   be known until after applying, resulting in an error. Hence, we need to pass it here.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  cidr_block = "10.2.0.0/16"

  vpc_secondary_cidr = true
  vpc_id             = data.aws_vpc.selected.id

  vpc_secondary_cidr_natgw = {
    "${data.aws_region.current.name}a" = {
      id = data.aws_nat_gateway.default.id
    }
  }

  subnets = {
    private = {
      name_prefix             = "secondary-private-natgw-connected"
      netmask                 = 18
      connect_to_public_natgw = true
    }
  }
}
