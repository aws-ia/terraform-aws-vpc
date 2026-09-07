mock_provider "aws" {
  override_during = plan

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.108.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }
}

run "reject_injected_isolated_route_table_without_opt_in" {
  command = plan

  module {
    source = "./tests/fixtures/computed-isolated-route-table"
  }
}
