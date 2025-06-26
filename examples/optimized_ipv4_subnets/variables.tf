variable "aws_region" {
  description = "AWS Region to create resources in."
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC cidr range"
  default     = "10.0.0.0/22"
}
