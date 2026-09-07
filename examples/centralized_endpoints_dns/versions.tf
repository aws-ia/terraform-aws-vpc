terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29, < 7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
