module "vpc" {
  source = "../.."

  vpc = {
    name = "dual-stack-vpc"
  }

  addressing = {
    primary = { cidr_block = "10.60.0.0/16" }
    secondary = {
      amazon-ipv6 = { ipv6 = { amazon_assigned = true } }
    }
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    public = {
      role = "public"
      ipv4 = { netmask = 24, cidr_index = 0 }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true, cidr_index = 0 }
      routing = {
        internet_gateway = true
      }
    }

    application = {
      role = "private"
      ipv4 = { netmask = 24, cidr_index = 1 }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true, cidr_index = 1 }
      routing = {
        nat_gateway     = true
        egress_only_igw = true
      }
    }

    ipv6-native = {
      role = "private"
      ipv6 = {
        secondary_cidr_key = "amazon-ipv6"
        native_only        = true
        auto_assign        = true
        cidr_index         = 2
      }
      routing = {
        dns64           = true
        egress_only_igw = true
      }
    }
  }

  nat_gateway = {
    mode = "regional"
  }

  tags = {
    Environment = "development"
    IPFamily    = "dual-stack"
  }
}
