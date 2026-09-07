mock_provider "aws" {
  override_during = plan

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

run "name_formats_and_tag_precedence" {
  command = plan

  variables {
    vpc = {
      name            = "naming-test"
      igw_name_format = "legacy-{vpc}-internet"
      igw_tags = {
        Boundary = "igw"
        Scope    = "gateway"
      }
    }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      public = {
        role                    = "public"
        name_prefix             = "legacy-public"
        name_format             = "{group}-{az}"
        route_table_name_format = "rt-{group}-{az}"
        ipv4                    = { cidrs_by_az = { "us-east-1a" = "10.0.0.0/24" } }
        tags = {
          Boundary = "group"
          Tier     = "edge"
          Name     = "must-not-win"
        }
      }
    }
    nat_gateway = {
      mode         = "single_az"
      az           = "us-east-1a"
      subnet_group = "public"
      name_format  = "nat-{group}-{az}"
      eip = {
        tags = { Allocation = "module-owned" }
      }
    }
    tags = {
      Boundary  = "global"
      ManagedBy = "terraform"
      Name      = "must-not-win"
    }
  }

  assert {
    condition = (
      aws_subnet.main["public/us-east-1a"].tags.Name == "legacy-public-us-east-1a" &&
      aws_route_table.main["public/us-east-1a"].tags.Name == "rt-legacy-public-us-east-1a" &&
      aws_internet_gateway.main[0].tags.Name == "legacy-naming-test-internet" &&
      aws_eip.nat["nat/us-east-1a"].tags.Name == "nat-legacy-public-us-east-1a" &&
      aws_nat_gateway.main["nat/us-east-1a"].tags.Name == "nat-legacy-public-us-east-1a"
    )
    error_message = "Explicit Name formats must replace the default formula for subnet, route table, IGW, EIP, and NAT Gateway resources."
  }

  assert {
    condition = (
      aws_subnet.main["public/us-east-1a"].tags.Boundary == "group" &&
      aws_subnet.main["public/us-east-1a"].tags.ManagedBy == "terraform" &&
      aws_route_table.main["public/us-east-1a"].tags.Boundary == "group" &&
      aws_internet_gateway.main[0].tags.Boundary == "igw" &&
      aws_eip.nat["nat/us-east-1a"].tags.Boundary == "group" &&
      aws_eip.nat["nat/us-east-1a"].tags.Allocation == "module-owned" &&
      aws_nat_gateway.main["nat/us-east-1a"].tags.Boundary == "group"
    )
    error_message = "Tag precedence must remain global < group/resource < generated Name across representative taggable resources."
  }
}


run "flow_log_name_formats_and_omission" {
  command = plan

  variables {
    vpc                = { name = "legacy-flow" }
    addressing         = { primary = { cidr_block = "10.1.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    tags               = { Name = "global-must-be-removed-or-overridden" }
    flow_logs = {
      default = {
        destination_type = "cloudwatch"
        name_format      = "{vpc}"
        cloudwatch_options = {
          name_format = ""
        }
        tags = { Fixture = "migration" }
      }
      unnamed = {
        destination_type = "s3"
        destination_arn  = "arn:aws:s3:::unnamed-flow-log-bucket"
        name_format      = ""
        tags             = { Name = "must-be-removed" }
      }
      native = {
        destination_type = "s3"
        destination_arn  = "arn:aws:s3:::native-flow-log-bucket"
        tags             = { Name = "must-not-win" }
      }
    }
  }

  assert {
    condition = (
      aws_flow_log.this["default"].tags.Name == "legacy-flow" &&
      !contains(keys(aws_cloudwatch_log_group.flow_logs["default"].tags), "Name") &&
      !contains(keys(aws_flow_log.this["unnamed"].tags), "Name") &&
      aws_flow_log.this["native"].tags.Name == "legacy-flow-native-flow-logs"
    )
    error_message = "Flow Log and log-group Name formats must be independent, preserve the default formula, and support explicit omission."
  }
}
