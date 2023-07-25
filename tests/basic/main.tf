#tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "name" {
  cidr_block = "10.0.0.0/16"
}

locals {
  myval = "drew"
}


