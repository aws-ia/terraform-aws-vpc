mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.141.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }
}

run "computed_aliases_keep_identity_validation_before_top_level_route" {
  command = plan

  module {
    source = "./tests/fixtures/computed-route-table-aliases"
  }

  assert {
    condition = (
      toset(output.ordering_shape.alias_keys) == toset(["application", "data"]) &&
      toset(output.ordering_shape.top_level_routes) == toset(["inspected-default/shared"])
    )
    error_message = "The computed-alias fixture must retain two logical identities and one downstream shared route instance."
  }
}
