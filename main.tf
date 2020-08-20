# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 0.13"
}

resource "random_pet" "name" {
  prefix = "aws-quickstart"
  length = 1
}

######################################
# Data sources to get VPC and subnets
######################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.name}_vpc"]
  }
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.vpc.id
}


module "VPC" {
  source = "./VPC"
  region = "ap-southeast-2"
  name   = "${random_pet.name.id}"
  create_ssh = "true"
  create_vpc = "true"
  cidr     = "10.0.0.0/16"
  public_subnets     = ["10.0.144.0/20", "10.0.160.0/20", "10.0.176.0/20"]
  private_subnets    = ["10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19"]
  database_subnets   = ["10.0.192.0/21", "10.0.200.0/21", "10.0.208.0/21"]
}

module "aurora" {
  source = "./aurora"
  region = "ap-southeast-2"
  name   = "${random_pet.name.id}"
  vpc_id = "" #leave blank to use the provided VPC or provide your VPC id if you have set create_vpc = "false" above.

}