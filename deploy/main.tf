# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 1.0.1 syntax, which means it is no longer compatible with any versions below 1.0.1.
# ----------------------------------------------------------------------------------------------------------------------
######################################
# Defaults
######################################
terraform {
  required_version = ">= 1.0.1"
  backend "remote" {}
}

provider "aws" {
  region = var.region
}

resource "random_string" "rand4" {
  length  = 4
  special = false
  upper   = false
}

module "vpc_label" {
  source    = "aws-ia/label/aws"
  version   = "0.0.1"
  region    = var.region
  namespace = var.namespace
  env       = var.env
  #account = var.account_name
  name      = "${var.name}-${random_string.rand4.result}"
  delimiter = var.delimiter
  tags      = tomap({ propogate_at_launch = "true", "terraform" = "true" })
}

######################################
# Create VPC
######################################
module "aws-ia_vpc" {
  source                    = "../modules/vpc"
  create_vpc                = var.create_vpc
  name                      = module.vpc_label.id
  region                    = var.region
  cidr                      = var.cidr
  public_subnets            = var.public_subnets
  private_subnets_a         = var.private_subnets_a
  private_subnets_b         = var.private_subnets_b
  tags                      = module.vpc_label.tags
  enable_dns_hostnames      = var.enable_dns_hostnames
  enable_dns_support        = var.enable_dns_support
  instance_tenancy          = var.instance_tenancy
  public_inbound_acl_rules  = var.public_inbound_acl_rules
  public_outbound_acl_rules = var.public_inbound_acl_rules
  custom_inbound_acl_rules  = var.custom_inbound_acl_rules
  custom_outbound_acl_rules = var.custom_outbound_acl_rules
  public_subnet_tags        = tomap(var.public_subnet_tags)
  private_subnet_tags       = tomap(var.private_subnet_tags)
}
