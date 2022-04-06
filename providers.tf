terraform {
  required_version = ">= 0.15.0"
  experiments      = [module_variable_optional_attrs]
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.72.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.15.0"
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
