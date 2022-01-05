terraform {
  required_providers {
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.9"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.68"
    }
  }
}

provider "awscc" {
  user_agent = [{
    product_name    = "terraform-awscc-vpc"
    product_version = "0.0.1"
    comment         = "V1/AWS-D69B4015/376222146"
  }]
}
