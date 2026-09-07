mock_provider "aws" {
  override_during = plan

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_vpc_ipv4_cidr_block_association" {
    defaults = {
      id         = "vpc-cidr-assoc-mock"
      cidr_block = "100.66.0.0/20"
    }
  }

  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      id              = "vpc-cidr-assoc-ipv6-mock"
      ipv6_cidr_block = "2001:db8:1200::/56"
    }
  }
}

run "primary_ipv4_cidr_only" {
  command = plan

  variables {
    vpc                = { name = "primary-cidr-output" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
  }

  assert {
    condition = (
      toset(keys(output.vpc_ipv4_cidr_blocks)) == toset(["primary"]) &&
      output.vpc_ipv4_cidr_blocks.primary == "10.0.0.0/16"
    )
    error_message = "The IPv4 VPC CIDR map must always contain only the primary key when no IPv4 secondary associations are configured."
  }
}

run "static_ipv4_secondaries_exclude_ipv6" {
  command = plan

  variables {
    vpc = { name = "static-secondary-cidr-output" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        blue      = { ipv4 = { cidr_block = "100.64.0.0/20" } }
        green     = { ipv4 = { cidr_block = "100.65.0.0/20" } }
        ipv6-only = { ipv6 = { cidr_block = "2001:db8:1200::/56", ipam_pool_id = "ipam-pool-ipv6" } }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
  }

  assert {
    condition = (
      toset(keys(output.vpc_ipv4_cidr_blocks)) == toset(["primary", "blue", "green"]) &&
      output.vpc_ipv4_cidr_blocks.primary == "10.0.0.0/16" &&
      output.vpc_ipv4_cidr_blocks.blue == "100.64.0.0/20" &&
      output.vpc_ipv4_cidr_blocks.green == "100.65.0.0/20" &&
      !contains(keys(output.vpc_ipv4_cidr_blocks), "ipv6-only")
    )
    error_message = "The IPv4 VPC CIDR map must preserve exact IPv4 addressing keys and values while excluding IPv6 secondary associations."
  }
}

run "ipam_netmask_secondary_passes_through_provider_cidr" {
  command = plan

  variables {
    vpc = { name = "ipam-secondary-cidr-output" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        managed = {
          ipv4 = {
            ipam_pool_id   = "ipam-pool-0123456789abcdef0"
            netmask_length = 20
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
  }

  assert {
    condition = (
      toset(keys(output.vpc_ipv4_cidr_blocks)) == toset(["primary", "managed"]) &&
      output.vpc_ipv4_cidr_blocks.primary == "10.0.0.0/16" &&
      output.vpc_ipv4_cidr_blocks.managed == "100.66.0.0/20"
    )
    error_message = "The IPAM-netmask key must be stable and pass through the provider-computed CIDR instead of coercing it to null."
  }
}
