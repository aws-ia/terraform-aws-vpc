
# VPC module (North Virginia)
module "nvirginia_vpc" {
  source = "../.."

  providers = { aws = aws.awsnvirginia }

  name                                 = "nvirginia-vpc"
  cidr_block                           = "10.0.0.0/24"
  vpc_assign_generated_ipv6_cidr_block = true
  az_count                             = 2

  core_network = {
    id  = aws_networkmanager_core_network.core_network.id
    arn = aws_networkmanager_core_network.core_network.arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }
  core_network_ipv6_routes = {
    workload = "::/0"
  }

  subnets = {
    workload = {
      netmask          = 28
      assign_ipv6_cidr = true
    }
    core_network = {
      netmask                = 28
      assign_ipv6_cidr       = true
      appliance_mode_support = true
      require_acceptance     = false

      tags = {
        env = "prod"
      }
    }
  }
}

# VPC module (Ireland)
module "ireland_vpc" {
  source = "../.."

  providers = { aws = aws.awsireland }

  name                                 = "ireland-vpc"
  cidr_block                           = "10.0.1.0/24"
  vpc_assign_generated_ipv6_cidr_block = true
  az_count                             = 2

  core_network = {
    id  = aws_networkmanager_core_network.core_network.id
    arn = aws_networkmanager_core_network.core_network.arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }
  core_network_ipv6_routes = {
    workload = "::/0"
  }
  subnets = {
    workload = {
      netmask          = 28
      assign_ipv6_cidr = true
    }
    core_network = {
      netmask            = 28
      assign_ipv6_cidr   = true
      require_acceptance = false

      tags = {
        env = "nonprod"
      }
    }
  }
}

# Global Network
resource "aws_networkmanager_global_network" "global_network" {
  provider = aws.awsnvirginia

  description = "Global Network - VPC module"
}

# Core Network
resource "aws_networkmanager_core_network" "core_network" {
  provider = aws.awsnvirginia

  description       = "Core Network - VPC module"
  global_network_id = aws_networkmanager_global_network.global_network.id

  create_base_policy   = true
  base_policy_document = data.aws_networkmanager_core_network_policy_document.policy.json

  tags = {
    Name = "Core Network - VPC module"
  }
}
