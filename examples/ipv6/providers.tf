
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.27.0"
    }
  }
}

# Provider definition
provider "aws" {
  region = var.aws_region
}

