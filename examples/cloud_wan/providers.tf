
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.22.0"
    }
  }
}

# Provider definition for N. Virginia Region
provider "aws" {
  region = var.cloud_wan_regions.nvirginia
  alias  = "awsnvirginia"
}

# Provider definition for Ireland Region
provider "aws" {
  region = var.cloud_wan_regions.ireland
  alias  = "awsireland"
}

