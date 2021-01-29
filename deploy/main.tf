# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------
######################################
# Defaults
######################################
terraform {
  required_version = ">= 0.13.5"
}

provider "aws" {
  region = var.region
}

resource "random_pet" "name" {
  prefix = "tfm-aws"
  length = 1
}

######################################
# Create VPC
######################################
module "quickstart_vpc" {
  source = "../modules/vpc"
  region = var.region
}