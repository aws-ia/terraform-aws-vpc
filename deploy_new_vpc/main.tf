# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------
######################################
# Defaults
######################################
terraform {
  required_version = ">= 0.13"
  
  backend "remote" {}
}


resource "random_pet" "name" {
  prefix = "aws-quickstart"
  length = 1
}

######################################
# Create VPC
######################################

module "quickstart_vpc" {
  source = "../modules/quickstart_vpc"
  region = "ap-southeast-2"
  name   = "${random_pet.name.id}"
  cidr     = "10.0.0.0/16"
  public_subnets      = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20", "10.0.176.0/20", "10.0.240.0/22", "10.0.244.0/22"]
  private_subnets_A   = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19", "10.0.232.0/22", "10.0.236.0/22"]
  priavte_subnets_B   =["10.0.192.0/21", "10.0.200.0/21", "10.0.208.0/21", "10.0.216.0/21","10.0.224.0/22", "10.0.228.0/22"]
}
