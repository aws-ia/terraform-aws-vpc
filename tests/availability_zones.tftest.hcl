mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1c", "us-east-1a", "us-east-1b"]
    }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }
}

run "count_sorts_and_slices_discovered_azs" {
  command = plan

  variables {
    vpc                = { name = "az-count-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { count = 2 }
    subnets = {
      app = { role = "private", ipv4 = { netmask = 24 } }
    }
  }

  assert {
    condition     = output.azs == tolist(["us-east-1a", "us-east-1b"])
    error_message = "count mode must sort discovery and select exactly the first N AZs."
  }

  assert {
    condition     = toset(keys(aws_subnet.main)) == toset(["app/us-east-1a", "app/us-east-1b"])
    error_message = "count mode must create resources only for the requested AZ slice."
  }
}
