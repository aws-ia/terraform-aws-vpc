module "vpc" {
  source = "../.."

  vpc = {
    name = "secure-isolated-vpc"
    dns = {
      enable_hostnames = true
      enable_support   = true
    }
  }

  addressing = {
    primary = { cidr_block = var.vpc_cidr }
  }

  availability_zones = {
    names = var.availability_zones
  }

  subnets = {
    enclave = {
      role = "isolated"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones :
          az => cidrsubnet(var.vpc_cidr, 8, index)
        }
      }
      network_acl = {
        ingress = {
          "100" = {
            protocol   = "tcp"
            action     = "allow"
            cidr_block = cidrsubnet(var.vpc_cidr, 4, 1)
            from_port  = 443
            to_port    = 443
          }
        }
        egress = {
          "100" = {
            protocol   = "tcp"
            action     = "allow"
            cidr_block = cidrsubnet(var.vpc_cidr, 4, 1)
            from_port  = 1024
            to_port    = 65535
          }
        }
        tags = { DataClassification = "restricted" }
      }
      tags = {
        DataClassification = "restricted"
      }
    }

    control = {
      role = "isolated"
      ipv4 = {
        cidrs_by_az = {
          for index, az in var.availability_zones :
          az => cidrsubnet(var.vpc_cidr, 8, index + 16)
        }
      }
      network_acl = {
        ingress = {
          "100" = {
            protocol   = "tcp"
            action     = "allow"
            cidr_block = cidrsubnet(var.vpc_cidr, 4, 0)
            from_port  = 1024
            to_port    = 65535
          }
        }
        egress = {
          "100" = {
            protocol   = "tcp"
            action     = "allow"
            cidr_block = cidrsubnet(var.vpc_cidr, 4, 0)
            from_port  = 443
            to_port    = 443
          }
        }
        tags = { Purpose = "offline-control-plane" }
      }
      tags = {
        Purpose = "offline-control-plane"
      }
    }
  }

  # Adopt and harden AWS-created defaults. This is intentionally opt-in.
  default_resources = {
    manage_security_group = true
    manage_network_acl    = true
    manage_route_table    = true
    tags = {
      SecurityBoundary = "no-internet-or-transit-routing"
    }
  }

  # Regional/account singleton: manage from exactly one module instance.
  vpc_block_public_access = {
    enabled                     = true
    internet_gateway_block_mode = "block-bidirectional"
  }

  dhcp_options = {
    enabled             = true
    domain_name         = "secure.internal"
    domain_name_servers = ["AmazonProvidedDNS"]
    ntp_servers         = ["169.254.169.123"]
    tags = {
      SecurityBoundary = "no-internet-or-transit-routing"
    }
  }

  tags = {
    Environment      = "restricted"
    SecurityBoundary = "no-internet-or-transit-routing"
  }
}
