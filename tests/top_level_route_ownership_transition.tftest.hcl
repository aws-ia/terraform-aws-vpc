mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.152.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-managed" }
  }

  mock_resource "aws_route" {
    defaults = { id = "r-managed" }
  }
}

run "apply_managed_route_tables" {
  command   = apply
  state_key = "top-level-route-ownership-transition"

  variables {
    vpc                = { name = "route-table-ownership-transition" }
    addressing         = { primary = { cidr_block = "10.152.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.152.0.0/24", us-east-1b = "10.152.1.0/24" } }
      }
    }
    routes = {
      services = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_peering", id = "pcx-services" }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_route_table.main)) == toset(["app/us-east-1a", "app/us-east-1b"]) &&
      toset(keys(aws_route.top_level)) == toset(["services/us-east-1a", "services/us-east-1b"])
    )
    error_message = "The seed apply must own two zonal route tables and two <route-key>/<az> top-level routes."
  }
}

run "plan_injected_shared_route_table" {
  command   = plan
  state_key = "top-level-route-ownership-transition"

  variables {
    vpc                = { name = "route-table-ownership-transition" }
    addressing         = { primary = { cidr_block = "10.152.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role               = "private"
        ipv4               = { cidrs_by_az = { us-east-1a = "10.152.0.0/24", us-east-1b = "10.152.1.0/24" } }
        manage_route_table = false
        route_table_key    = "shared-app"
        route_table_id     = "rtb-injected-shared-app"
      }
    }
    routes = {
      services = {
        from_group  = "app"
        destination = { type = "ipv4_cidr", value = "10.200.0.0/16" }
        target      = { type = "vpc_peering", id = "pcx-services" }
      }
    }
  }

  assert {
    condition = (
      length(aws_route_table.main) == 0 &&
      keys(aws_route.top_level) == ["services/shared"] &&
      aws_route.top_level["services/shared"].route_table_id == "rtb-injected-shared-app" &&
      !contains(keys(aws_route.top_level), "services/us-east-1a") &&
      !contains(keys(aws_route.top_level), "services/us-east-1b")
    )
    error_message = "The injected plan must remove managed table instances, replace zonal route addresses, and create only <route-key>/shared on the injected table."
  }
}
