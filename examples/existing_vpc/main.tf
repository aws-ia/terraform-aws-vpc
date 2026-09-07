resource "aws_vpc" "external" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "externally-owned-vpc"
    ManagedBy = "example-root"
  }
}

resource "aws_internet_gateway" "external" {
  vpc_id = aws_vpc.external.id

  tags = {
    Name      = "externally-owned-igw"
    ManagedBy = "example-root"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.external.id

  tags = {
    Name      = "externally-owned-public-routes"
    ManagedBy = "example-root"
  }
}

resource "aws_eip" "nat" {
  for_each = toset(var.availability_zones)

  domain = "vpc"

  tags = {
    Name      = "externally-owned-nat-${each.key}"
    ManagedBy = "example-root"
  }
}

module "vpc" {
  source = "../.."

  vpc = {
    name       = "existing-vpc-boundary"
    create     = false
    id         = aws_vpc.external.id
    igw_create = false
    igw_id     = aws_internet_gateway.external.id
  }

  # The module discovers the injected VPC's primary IPv4 CIDR through the AWS
  # data source; subnet CIDRs remain explicit caller-owned configuration.
  addressing = {
    primary = {}
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    public = {
      role = "public"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones :
          az => cidrsubnet(var.vpc_cidr, 8, index)
        }
      }
      manage_route_table = false
      route_table_key    = "external-public"
      route_table_id     = aws_route_table.public.id
      routing = {
        internet_gateway = true
      }
    }

    application = {
      role = "private"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones :
          az => cidrsubnet(var.vpc_cidr, 8, index + 16)
        }
      }
      routing = {
        nat_gateway = true
      }
    }
  }

  nat_gateway = {
    mode = "regional"
    eip = {
      mode = "existing"
      allocation_ids = {
        for az, eip in aws_eip.nat : az => eip.id
      }
    }
  }

  tags = {
    Pattern = "create-or-inject"
  }
}
