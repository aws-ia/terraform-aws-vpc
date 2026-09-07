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

run "allow_computed_isolated_route_table_with_explicit_opt_in" {
  command = plan

  module {
    source = "./tests/fixtures/computed-isolated-route-table"
  }

  variables {
    accept_uninspected = true
  }

  assert {
    condition     = output.route_table_association_count == 1
    error_message = "A computed isolated route-table ID may proceed only when the caller explicitly accepts an uninspected table."
  }
}
