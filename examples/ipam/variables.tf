variable "aws_region" {
  description = "AWS Region containing the IPAM pools."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Explicit AZ order for subnet identity."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_ipv4_ipam_pool_id" {
  description = "IPv4 IPAM pool from which the VPC receives its primary /16."
  type        = string
  default     = "ipam-pool-0123456789abcdef0"
}

variable "secondary_ipv4_ipam_pool_id" {
  description = "IPv4 IPAM pool used for the named analytics secondary /20 association."
  type        = string
  default     = "ipam-pool-1123456789abcdef0"
}

variable "subnet_ipv4_ipam_pool_id" {
  description = "IPv4 IPAM pool used for primary-CIDR application subnets."
  type        = string
  default     = "ipam-pool-2123456789abcdef0"
}

variable "secondary_subnet_ipv4_ipam_pool_id" {
  description = "IPv4 IPAM pool used for analytics subnets in the secondary association."
  type        = string
  default     = "ipam-pool-3123456789abcdef0"
}

variable "vpc_ipv6_ipam_pool_id" {
  description = "IPv6 IPAM pool from which the VPC receives its /56."
  type        = string
  default     = "ipam-pool-4123456789abcdef0"
}

variable "subnet_ipv6_ipam_pool_id" {
  description = "IPv6 IPAM pool used for subnet /64 allocations."
  type        = string
  default     = "ipam-pool-5123456789abcdef0"
}
