mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_vpclattice_service_network_vpc_association" {
    defaults = { id = "snva-mock" }
  }
}

run "private_dns_pins_aws_default" {
  command = plan

  variables {
    vpc                = { name = "lattice-default-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    vpc_lattice = {
      enabled                    = true
      service_network_identifier = "sn-0123456789abcdef0"
      private_dns_enabled        = true
    }
  }

  assert {
    condition = (
      length(aws_vpclattice_service_network_vpc_association.this["vpc"].dns_options) == 1 &&
      aws_vpclattice_service_network_vpc_association.this["vpc"].dns_options[0].private_dns_preference == "VERIFIED_DOMAINS_ONLY"
    )
    error_message = "Private DNS must configure AWS's VERIFIED_DOMAINS_ONLY default so an AWS-populated dns_options block cannot force replacement on the next plan."
  }
}

run "private_dns_supports_specified_domains" {
  command = plan

  variables {
    vpc                = { name = "lattice-specified-test" }
    addressing         = { primary = { cidr_block = "10.1.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    vpc_lattice = {
      enabled                    = true
      service_network_identifier = "sn-0123456789abcdef0"
      private_dns_enabled        = true
      dns_options = {
        private_dns_preference        = "SPECIFIED_DOMAINS_ONLY"
        private_dns_specified_domains = ["internal.example.com"]
      }
    }
  }

  assert {
    condition = (
      aws_vpclattice_service_network_vpc_association.this["vpc"].dns_options[0].private_dns_preference == "SPECIFIED_DOMAINS_ONLY" &&
      aws_vpclattice_service_network_vpc_association.this["vpc"].dns_options[0].private_dns_specified_domains == toset(["internal.example.com"])
    )
    error_message = "Specified-domain preferences must pass their validated domain set to the provider."
  }
}

run "reject_domains_with_verified_only" {
  command = plan

  variables {
    vpc                = { name = "lattice-negative-test" }
    addressing         = { primary = { cidr_block = "10.2.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    vpc_lattice = {
      enabled                    = true
      service_network_identifier = "sn-0123456789abcdef0"
      private_dns_enabled        = true
      dns_options = {
        private_dns_specified_domains = ["internal.example.com"]
      }
    }
  }

  expect_failures = [var.vpc_lattice]
}
