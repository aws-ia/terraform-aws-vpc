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
  source                 = "../modules/vpc"
  create_vpc             = var.create_vpc
  name                   = module.vpc_label.id
  cidr                   = var.cidr
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_a_cidrs = var.private_subnet_a_cidrs
  tags                   = module.vpc_label.tags
  enable_dns_hostnames   = var.enable_dns_hostnames
  enable_dns_support     = var.enable_dns_support
  instance_tenancy       = var.instance_tenancy
  public_subnet_tags     = tomap(var.public_subnet_tags)
  private_subnet_tags    = tomap(var.private_subnet_tags)
  create_vpc_flow_logs   = var.create_vpc_flow_logs
  flog_log_iam_role_arn  = var.flog_log_iam_role_arn
  log_destination        = var.log_destination
  log_destination_type   = var.log_destination_type
  log_format             = var.log_format
  traffic_type           = var.traffic_type
  enriched_meta_data     = var.enriched_meta_data
}
