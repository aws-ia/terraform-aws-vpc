terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.59.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  max_retries                 = 0

  endpoints {
    ec2 = "http://127.0.0.1:1"
  }
}

resource "aws_vpc_ipv6_cidr_block_association" "secondary" {
  for_each = { v4-ipv6 = true }

  vpc_id                           = "vpc-0123456789abcdef0"
  assign_generated_ipv6_cidr_block = true
}
