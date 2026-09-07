resource "aws_vpclattice_service_network" "enterprise" {
  name      = "enterprise-service-network"
  auth_type = "AWS_IAM"

  tags = {
    Environment = "example"
  }
}

module "vpc" {
  source = "../.."

  vpc = {
    name             = "enterprise-vpc"
    instance_tenancy = "default"
    dns = {
      enable_hostnames = true
      enable_support   = true
    }
    tags = { CostCenter = "platform-team" }
  }

  addressing = {
    primary = {
      cidr_block = "10.0.0.0/16"
    }
    secondary = {
      shared-services = {
        ipv4 = { cidr_block = "100.64.0.0/20" }
      }
      amazon-ipv6 = {
        ipv6 = { amazon_assigned = true }
      }
    }
  }

  availability_zones = {
    names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  }

  subnets = {
    public = {
      role = "public"
      ipv4 = { netmask = 24 }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true }
      routing = {
        internet_gateway = true
      }
      public_options = {
        map_public_ip = false
      }
      network_acl = {
        ingress = {
          "100" = { protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0", from_port = 80, to_port = 80 }
          "110" = { protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0", from_port = 443, to_port = 443 }
          "120" = { protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 }
          "130" = { protocol = "tcp", action = "allow", ipv6_cidr_block = "::/0", from_port = 80, to_port = 80 }
          "140" = { protocol = "tcp", action = "allow", ipv6_cidr_block = "::/0", from_port = 443, to_port = 443 }
          "150" = { protocol = "tcp", action = "allow", ipv6_cidr_block = "::/0", from_port = 1024, to_port = 65535 }
        }
        egress = {
          "100" = { protocol = "-1", action = "allow", cidr_block = "0.0.0.0/0" }
          "110" = { protocol = "-1", action = "allow", ipv6_cidr_block = "::/0" }
        }
        tags = { Tier = "public" }
      }
    }

    application = {
      role = "private"
      ipv4 = {
        cidrs_by_az = { "eu-west-1a" = "10.0.32.0/20", "eu-west-1b" = "10.0.48.0/20", "eu-west-1c" = "10.0.64.0/20" }
      }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true }
      routing = {
        nat_gateway               = true
        egress_only_igw           = true
        s3_gateway_endpoint       = true
        dynamodb_gateway_endpoint = true
      }
      network_acl = {
        ingress = {
          "100" = { protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 }
          "110" = { protocol = "udp", action = "allow", cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 }
          "120" = { protocol = "tcp", action = "allow", ipv6_cidr_block = "::/0", from_port = 1024, to_port = 65535 }
          "130" = { protocol = "udp", action = "allow", ipv6_cidr_block = "::/0", from_port = 1024, to_port = 65535 }
        }
        egress = {
          "100" = { protocol = "-1", action = "allow", cidr_block = "0.0.0.0/0" }
          "110" = { protocol = "-1", action = "allow", ipv6_cidr_block = "::/0" }
        }
        tags = { Tier = "application" }
      }
      tags = { Tier = "application" }
    }

    data = {
      role = "isolated"
      ipv4 = {
        cidrs_by_az = { "eu-west-1a" = "10.0.80.0/22", "eu-west-1b" = "10.0.84.0/22", "eu-west-1c" = "10.0.88.0/22" }
      }
      routing = {
        s3_gateway_endpoint       = true
        dynamodb_gateway_endpoint = true
      }
      network_acl = {
        ingress = {
          "100" = { protocol = "tcp", action = "allow", cidr_block = "10.0.32.0/19", from_port = 5432, to_port = 5432 }
          "110" = { protocol = "tcp", action = "allow", cidr_block = "10.0.64.0/19", from_port = 5432, to_port = 5432 }
        }
        egress = {
          "100" = { protocol = "tcp", action = "allow", cidr_block = "10.0.32.0/19", from_port = 1024, to_port = 65535 }
          "110" = { protocol = "tcp", action = "allow", cidr_block = "10.0.64.0/19", from_port = 1024, to_port = 65535 }
        }
        tags = { Tier = "data" }
      }
      tags = { Tier = "data", Compliance = "pci-dss" }
    }

    endpoints = {
      role = "isolated"
      ipv4 = {
        cidrs_by_az        = { "eu-west-1a" = "100.64.0.0/26", "eu-west-1b" = "100.64.0.64/26", "eu-west-1c" = "100.64.0.128/26" }
        secondary_cidr_key = "shared-services"
      }
      routing = {
        s3_gateway_endpoint       = true
        dynamodb_gateway_endpoint = true
      }
      network_acl = {
        ingress = {
          "100" = { protocol = "tcp", action = "allow", cidr_block = "10.0.0.0/16", from_port = 443, to_port = 443 }
          "110" = { protocol = "tcp", action = "allow", cidr_block = "100.64.0.0/20", from_port = 443, to_port = 443 }
        }
        egress = {
          "100" = { protocol = "tcp", action = "allow", cidr_block = "10.0.0.0/16", from_port = 1024, to_port = 65535 }
          "110" = { protocol = "tcp", action = "allow", cidr_block = "100.64.0.0/20", from_port = 1024, to_port = 65535 }
        }
        tags = { Tier = "vpc-endpoints" }
      }
      tags = { Tier = "vpc-endpoints" }
    }
  }

  nat_gateway = {
    mode = "regional"
  }

  gateway_endpoints = {
    s3       = { service = "s3" }
    dynamodb = { service = "dynamodb" }
  }

  # Module-owned CloudWatch destination and delivery role keep the example
  # deployable without pre-existing logging infrastructure.
  flow_logs = {
    archive = {
      destination_type = "cloudwatch"
      traffic_type     = "ALL"
      cloudwatch_options = {
        retention_in_days = 365
      }
    }
  }

  vpc_lattice = {
    enabled                    = true
    service_network_identifier = aws_vpclattice_service_network.enterprise.id
    private_dns_enabled        = true
    tags                       = { Tier = "service-network" }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
