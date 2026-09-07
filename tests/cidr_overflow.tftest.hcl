mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_vpc_ipv4_cidr_block_association" {
    defaults = {
      id         = "vpc-cidr-assoc-ipv4"
      cidr_block = "100.64.0.0/28"
    }
  }

  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      id              = "vpc-cidr-assoc-ipv6"
      ipv6_cidr_block = "2001:db8:1000::/64"
    }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }
}

run "reject_apply_known_ipv4_calculation_overflow" {
  command = apply

  variables {
    vpc = { name = "ipv4-overflow" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        constrained = {
          ipv4 = {
            ipam_pool_id   = "ipam-pool-0123456789abcdef0"
            netmask_length = 28
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = {
          netmask            = 28
          cidr_index         = 1
          secondary_cidr_key = "constrained"
        }
      }
    }
  }

  expect_failures = [
    terraform_data.cidr_pinning_validation[0],
    aws_subnet.main["app/us-east-1a"],
  ]
}

run "reject_apply_known_ipv6_calculation_overflow" {
  command = apply

  variables {
    vpc = { name = "ipv6-overflow" }
    addressing = {
      primary = { cidr_block = "10.1.0.0/16" }
      secondary = {
        constrained = {
          ipv6 = {
            ipam_pool_id   = "ipam-pool-0123456789abcdef0"
            netmask_length = 60
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.1.0.0/24" } }
        ipv6 = {
          secondary_cidr_key = "constrained"
          auto_assign        = true
          cidr_index         = 1
        }
      }
    }
  }

  expect_failures = [
    terraform_data.ipv6_cidr_calculation_validation[0],
    aws_subnet.main["app/us-east-1a"],
  ]
}
