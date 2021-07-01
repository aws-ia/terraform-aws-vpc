# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.15.1 syntax, which means it is no longer compatible with any versions below 0.15.1.
# ----------------------------------------------------------------------------------------------------------------------
######################################
# Defaults
######################################
terraform {
  required_version = ">= 0.15.1"
  backend "remote" {}
}

provider "aws" {
  region  = var.region
  profile = "default"
}

resource "random_pet" "name" {
  prefix = "id"
  length = 1
}

######################################
# Create VPC
######################################

module "aws-vpc" {
  source                    = "./modules/vpc"
  region                    = var.region
  name                      = random_pet.name.id
  cidr                      = var.cidr
  public_subnets            = var.public_subnets
  private_subnets_A         = var.private_subnets_A
  private_subnets_B         = var.private_subnets_B
  tags                      = var.tags
  enable_dns_hostnames      = var.enable_dns_hostnames
  enable_dns_support        = var.enable_dns_support
  instance_tenancy          = var.instance_tenancy
  public_inbound_acl_rules  = var.public_inbound_acl_rules
  public_outbound_acl_rules = var.public_inbound_acl_rules
  custom_inbound_acl_rules  = var.custom_inbound_acl_rules
  custom_outbound_acl_rules = var.custom_outbound_acl_rules

}