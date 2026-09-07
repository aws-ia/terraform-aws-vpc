mock_provider "aws" {
  override_during = plan

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.121.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }
}

run "generic_peering_and_gwlbe_routes" {
  command = plan

  variables {
    vpc                = { name = "generic-routes" }
    addressing         = { primary = { cidr_block = "10.121.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.121.0.0/24" } }
        routes = {
          peer-services = {
            destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
            target      = { type = "vpc_peering", id = "pcx-documentation" }
          }
          inspect-default = {
            destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
            target      = { type = "vpc_endpoint", id = "vpce-documentation" }
          }
        }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_route.custom)) == toset([
        "app/us-east-1a/custom/inspect-default",
        "app/us-east-1a/custom/peer-services",
      ]) &&
      aws_route.custom["app/us-east-1a/custom/peer-services"].vpc_peering_connection_id == "pcx-documentation" &&
      aws_route.custom["app/us-east-1a/custom/inspect-default"].vpc_endpoint_id == "vpce-documentation"
    )
    error_message = "Generic route keys must remain caller-owned while peering and GWLBe targets map to their provider arguments."
  }
}

run "reject_generic_collision_with_opinionated_route" {
  command = plan

  variables {
    vpc                = { name = "generic-collision" }
    addressing         = { primary = { cidr_block = "10.122.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      public = {
        role = "public"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.122.0.0/24" } }
        routes = {
          duplicate-default = {
            destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
            target      = { type = "vpc_peering", id = "pcx-documentation" }
          }
        }
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}
