variable "aws_region" {
  description = "AWS Region in which to create the dual-stack example."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Explicit AZ order for the dual-stack topology."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct AZs."
  }
}
