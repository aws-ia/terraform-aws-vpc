
variable "aws_region" {
  description = "AWS Region."
  type        = string

  default = "us-east-1"
}

variable "azs" {
  type        = list(string)
  description = "A list of AZs to use. e.g. `azs = [\"us-east-1a\",\"us-east-1c\"]` Incompatible with `az_count`"
  default = [
    "us-east-1a",
    "us-east-1c",
  ]
}

variable "cidr_block" {
  type        = string
  description = "IPv4 CIDR range to assign to VPC if creating VPC or to associate as a secondary IPv6 CIDR. Overridden by var.vpc_id output from data.aws_vpc."
  default     = "10.0.0.0/16"
}

