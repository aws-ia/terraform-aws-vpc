variable "aws_region" {
  description = "AWS Region in which to create the isolated VPC."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Two explicit AZs used by the isolated subnet groups."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct AZs."
  }
}

variable "vpc_cidr" {
  description = "Primary IPv4 CIDR for the isolated VPC."
  type        = string
  default     = "10.90.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && !strcontains(var.vpc_cidr, ":")
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}
