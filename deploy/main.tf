# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------
######################################
# Defaults
######################################
terraform {
  required_version = ">= 0.13.5"
  backend "remote" {}
}

provider "aws" {
  region = var.region
}

#resource "random_pet" "name" {
#  prefix = "tfm-aws"
#  length = 1
#}

module "quickstart_vpc_label" {
  source    = "git@github.com:aws-quickstart/terraform-aws-label.git"
  region    = var.region
  namespace = var.namespace
  env       = var.env
  #account = var.account_name
  name      = var.name
  delimiter = var.delimiter
  tags      = map("propogate_at_launch", "true", "terraform", "true")
}

######################################
# Create VPC
######################################
module "quickstart_vpc" {
  source            = "../modules/vpc"
  create_vpc        = var.create_vpc
  name              = module.quickstart_vpc_label.id
  region            = var.region
  cidr              = var.cidr
  public_subnets    = var.public_subnets
  private_subnets_A = var.private_subnets_A
  private_subnets_B = var.private_subnets_B
  tags              = module.quickstart_vpc_label.tags
}
