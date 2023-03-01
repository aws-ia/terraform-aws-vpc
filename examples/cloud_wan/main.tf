
# VPC module (North Virginia)
module "nvirginia_vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 4.0.0"
  providers = { aws = aws.awsnvirginia }

  name       = "nvirginia-vpc"
  cidr_block = "10.0.0.0/24"
  az_count   = 2

  core_network = {
    id  = aws_networkmanager_core_network.core_network.id
    arn = aws_networkmanager_core_network.core_network.arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    workload = { netmask = 28 }
    core_network = {
      netmask                = 28
      ipv6_support           = false
      appliance_mode_support = true
      require_acceptance     = true
      accept_attachment      = true

      tags = {
        env = "prod"
      }
    }
  }
}

# VPC module (Ireland)
module "ireland_vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 4.0.0"
  providers = { aws = aws.awsireland }

  name       = "ireland-vpc"
  cidr_block = "10.0.1.0/24"
  az_count   = 2

  core_network = {
    id  = aws_networkmanager_core_network.core_network.id
    arn = aws_networkmanager_core_network.core_network.arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    workload = { netmask = 28 }
    core_network = {
      netmask            = 28
      ipv6_support       = false
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
  policy_document   = jsonencode(jsondecode(data.aws_networkmanager_core_network_policy_document.policy.json))

  tags = {
    Name = "Core Network - VPC module"
  }
}
