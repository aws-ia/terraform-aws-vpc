
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.27.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "= 0.33.0"
    }
  }
}

# Provider definitios for N. Virginia Region
provider "aws" {
  region = var.cloud_wan_regions.nvirginia
  alias  = "awsnvirginia"
}

provider "awscc" {
  region = var.cloud_wan_regions.nvirginia
  alias  = "awsccnvirginia"
}

# Provider definitios for Ireland Region
provider "aws" {
  region = var.cloud_wan_regions.ireland
  alias  = "awsireland"
}

provider "awscc" {
  region = var.cloud_wan_regions.ireland
  alias  = "awsccireland"
}