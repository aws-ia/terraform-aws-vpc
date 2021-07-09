variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
}

variable "name" {
  type        = string
  description = "The name of the resources"
}

variable "region" {
  type        = string
  description = "The name of the region you wish to deploy into"
}

variable "tags" {
  type        = map(string)
  description = "tags, which could be used for additional tags"
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets"
  type        = map(string)
  default     = {}
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  type        = string
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
}

variable "private_subnets_A" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
}

variable "private_subnets_B" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
}

variable "public_inbound_acl_rules" {
  description = "Public subnets inbound network ACLs"
  type        = list(map(string))
}

variable "public_outbound_acl_rules" {
  description = "Public subnets outbound network ACLs"
  type        = list(map(string))
}
variable "custom_inbound_acl_rules" {
  description = "Custom subnets inbound network ACLs"
  type        = list(map(string))
}
variable "custom_outbound_acl_rules" {
  description = "Custom subnets outbound network ACLs"
  type        = list(map(string))
}
