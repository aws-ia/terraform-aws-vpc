
# VPC module (North Virginia)
module "nvirginia_vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 3.0.2"

  providers = {
    aws   = aws.awsnvirginia
    awscc = awscc.awsccnvirginia
  }

  name       = "nvirginia-vpc"
  cidr_block = "10.0.0.0/24"
  az_count   = 2

  core_network = {
    id  = awscc_networkmanager_core_network.core_network.core_network_id
    arn = awscc_networkmanager_core_network.core_network.core_network_arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    workload = { netmask = 28 }
    core_network = {
      netmask            = 28
      ipv6_support       = false
      require_acceptance = true
      accept_attachment  = true

      tags = {
        env = "prod"
      }
    }
  }
}

# VPC module (Ireland)
module "ireland_vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 3.0.2"

  providers = {
    aws   = aws.awsireland
    awscc = awscc.awsccireland
  }

  name       = "ireland-vpc"
  cidr_block = "10.0.1.0/24"
  az_count   = 2

  core_network = {
    id  = awscc_networkmanager_core_network.core_network.core_network_id
    arn = awscc_networkmanager_core_network.core_network.core_network_arn
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
resource "awscc_networkmanager_global_network" "global_network" {
  provider = awscc.awsccnvirginia

  description = "Global Network - VPC module"
}

# Core Network
resource "awscc_networkmanager_core_network" "core_network" {
  provider = awscc.awsccnvirginia

  description       = "Core Network - VPC module"
  global_network_id = awscc_networkmanager_global_network.global_network.id
  policy_document   = jsonencode(jsondecode(data.aws_networkmanager_core_network_policy_document.policy.json))

  tags = [{
    key   = "Name",
    value = "Core Network - VPC module"
  }]
}
