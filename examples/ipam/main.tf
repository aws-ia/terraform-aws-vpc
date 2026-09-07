module "vpc" {
  source = "../.."

  vpc = {
    name = "ipam-vpc"
  }

  addressing = {
    primary = {
      ipam_pool_id   = var.vpc_ipv4_ipam_pool_id
      netmask_length = 16
    }
    secondary = {
      analytics = {
        ipv4 = {
          ipam_pool_id   = var.secondary_ipv4_ipam_pool_id
          netmask_length = 20
        }
      }
      legacy = {
        ipv4 = { cidr_block = "100.64.0.0/20" }
      }
      ipv6-ipam = {
        ipv6 = {
          ipam_pool_id   = var.vpc_ipv6_ipam_pool_id
          netmask_length = 56
        }
      }
    }
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    application = {
      role = "private"
      ipv4 = {
        ipam_pool_id   = var.subnet_ipv4_ipam_pool_id
        netmask_length = 24
      }
      ipv6 = {
        secondary_cidr_key = "ipv6-ipam"
        ipam_pool_id       = var.subnet_ipv6_ipam_pool_id
        netmask_length     = 64
        auto_assign        = true
      }
    }

    analytics = {
      role = "private"
      ipv4 = {
        ipam_pool_id       = var.secondary_subnet_ipv4_ipam_pool_id
        netmask_length     = 24
        secondary_cidr_key = "analytics"
      }
      ipv6 = {
        secondary_cidr_key = "ipv6-ipam"
        ipam_pool_id       = var.subnet_ipv6_ipam_pool_id
        netmask_length     = 64
        auto_assign        = true
      }
    }


    ipv6-native = {
      role = "private"
      ipv6 = {
        secondary_cidr_key = "ipv6-ipam"
        ipam_pool_id       = var.subnet_ipv6_ipam_pool_id
        netmask_length     = 64
        native_only        = true
        auto_assign        = true
      }
    }
    legacy = {
      role = "isolated"
      ipv4 = {
        cidrs_by_az        = { "us-east-1a" = "100.64.0.0/24", "us-east-1b" = "100.64.1.0/24" }
        secondary_cidr_key = "legacy"
      }
    }
  }

  tags = {
    AddressManager = "vpc-ipam"
    Environment    = "development"
  }
}
