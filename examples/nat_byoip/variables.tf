variable "aws_region" {
  description = "AWS Region in which to create the three demonstration VPCs."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Two explicit AZs used by every demonstration VPC."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct AZs."
  }
}

variable "public_ipv4_pool" {
  description = "Customer-owned EC2 public IPv4 pool used by eip.mode=byoip_pool."
  type        = string
  default     = "ipv4pool-ec2-0123456789abcdef0"
}

variable "existing_eip_allocation_ids" {
  description = "Existing EIP allocation IDs keyed by the selected NAT AZs."
  type        = map(string)
  default = {
    us-east-1a = "eipalloc-0123456789abcdef0"
    us-east-1b = "eipalloc-0123456789abcdef1"
  }
}
