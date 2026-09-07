variable "aws_region" {
  description = "AWS Region in which to build the ownership-boundary example."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Two explicit AZs used by the injected VPC topology."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct AZs."
  }
}

variable "vpc_cidr" {
  description = "Primary IPv4 CIDR of the VPC created outside the module."
  type        = string
  default     = "10.80.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && !strcontains(var.vpc_cidr, ":")
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}
