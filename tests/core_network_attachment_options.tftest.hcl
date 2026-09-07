# Cloud WAN VPC attachment options: routing_policy_label, dns_support,
# security_group_referencing (ported from v4.9.0). Defaults must be null so the
# AWS service defaults apply and existing attachments see no diff.

mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.99.0.0/16"
    }
  }
  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }
  mock_resource "aws_networkmanager_vpc_attachment" {
    defaults = { id = "attachment-created" }
  }
}

run "options_propagate_to_attachment" {
  command = plan
  variables {
    vpc                = { name = "cwan-options-set" }
    addressing         = { primary = { cidr_block = "10.99.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.99.0.0/28" } }
        core_network_options = {
          id                         = "cnet-0123456789abcdef0"
          routing_policy_label       = "prod-attachments"
          dns_support                = true
          security_group_referencing = false
        }
      }
    }
  }

  assert {
    condition     = aws_networkmanager_vpc_attachment.this["vpc"].routing_policy_label == "prod-attachments"
    error_message = "routing_policy_label was not propagated to the Cloud WAN VPC attachment"
  }

  assert {
    condition     = [for o in aws_networkmanager_vpc_attachment.this["vpc"].options : o.dns_support][0] == true
    error_message = "dns_support was not propagated to the Cloud WAN VPC attachment options"
  }

  assert {
    condition     = [for o in aws_networkmanager_vpc_attachment.this["vpc"].options : o.security_group_referencing_support][0] == false
    error_message = "security_group_referencing was not propagated to the Cloud WAN VPC attachment options"
  }
}

run "options_default_to_null" {
  command = plan
  variables {
    vpc                = { name = "cwan-options-default" }
    addressing         = { primary = { cidr_block = "10.99.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      cwan = {
        role = "core_network"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.99.0.0/28" } }
        core_network_options = {
          id = "cnet-0123456789abcdef0"
        }
      }
    }
  }

  assert {
    condition     = aws_networkmanager_vpc_attachment.this["vpc"].routing_policy_label == null
    error_message = "routing_policy_label must default to null (AWS default preserved)"
  }
}
