mock_provider "aws" {
  override_during = plan

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-documentation"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-documentation"
      cidr_block = "10.110.0.0/16"
    }
  }
  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-documentation"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-documentation"
    }
  }
  mock_resource "aws_route_table" {
    defaults = { id = "rtb-documentation" }
  }
  mock_resource "aws_eip" {
    defaults = { id = "eipalloc-documentation" }
  }
  mock_resource "aws_nat_gateway" {
    defaults = { id = "nat-documentation" }
  }
}

run "role_and_connectivity_are_independent" {
  command = plan

  variables {
    vpc                = { name = "connectivity-output-test" }
    addressing         = { primary = { cidr_block = "10.110.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      public = {
        role = "public"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.110.0.0/24" } }
      }
      app_with_nat = {
        role    = "private"
        ipv4    = { cidrs_by_az = { us-east-1a = "10.110.1.0/24" } }
        routing = { nat_gateway = true }
      }
      app_without_egress = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.110.2.0/24" } }
      }
      isolated = {
        role = "isolated"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.110.3.0/24" } }
      }
    }
    nat_gateway = {
      mode         = "single_az"
      az           = "us-east-1a"
      subnet_group = "public"
    }
  }

  assert {
    condition = (
      output.subnet_connectivity_by_group_by_az.public["us-east-1a"].igw &&
      output.subnet_connectivity_by_group_by_az.public["us-east-1a"].internet &&
      output.subnet_connectivity_by_group_by_az.app_with_nat["us-east-1a"].nat &&
      output.subnet_connectivity_by_group_by_az.app_with_nat["us-east-1a"].internet &&
      !output.subnet_connectivity_by_group_by_az.app_without_egress["us-east-1a"].internet &&
      !output.subnet_connectivity_by_group_by_az.isolated["us-east-1a"].internet
    )
    error_message = "Connectivity booleans must distinguish private groups with and without NAT independently of role."
  }

  assert {
    condition = (
      length(output.subnet_ids_with_nat_by_az["us-east-1a"]) == 1 &&
      length(output.subnet_ids_without_internet_by_az["us-east-1a"]) == 2
    )
    error_message = "Capability views must return one NAT subnet and both no-Internet subnets."
  }

  assert {
    condition = (
      !output.subnet_connectivity_by_group_by_az.isolated["us-east-1a"].eigw &&
      !output.subnet_connectivity_by_group_by_az.isolated["us-east-1a"].tgw &&
      !output.subnet_connectivity_by_group_by_az.isolated["us-east-1a"].core_network &&
      !output.subnet_connectivity_by_group_by_az.isolated["us-east-1a"].s3_gateway_endpoint &&
      !output.subnet_connectivity_by_group_by_az.isolated["us-east-1a"].dynamodb_gateway_endpoint
    )
    error_message = "The connectivity object must expose all frozen capability booleans."
  }
}
