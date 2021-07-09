variable "region" {
  description = "Sets the region"
  type        = string
  default     = "us-west-2"
}
variable "namespace" {
  description = "Namespace, which could be your organiation name, e.g. amazon"
  default     = "myorg"
}
variable "env" {
  description = "Environment, e.g. 'sit', 'uat', 'prod' etc"
  default     = "dev"
}
variable "account" {
  description = "Account, which could be AWS Account Name or Number"
  default     = "test"
}
variable "name" {
  description = "vpc name"
  default     = "vpc1"
}
variable "delimiter" {
  description = "Delimiter, which could be used between name, namespace and env"
  default     = "-"
}
variable "tags" {
  default     = {}
  description = "Tags, which could be used for additional tags"
}
variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}
variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}
variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  type        = string
  default     = "default"
}
variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.0.0.0/16"
}
variable "public_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
}
variable "private_subnets_A" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = ["10.0.96.0/19", "10.0.232.0/22", "10.0.236.0/22"]
}
variable "private_subnets_B" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = []
}
variable "public_inbound_acl_rules" {
  description = "Public subnets inbound network ACLs"
  type        = list(map(string))

  default = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
  ]
}
variable "public_outbound_acl_rules" {
  description = "Public subnets outbound network ACLs"
  type        = list(map(string))

  default = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
  ]
}
variable "custom_inbound_acl_rules" {
  description = "Custom subnets inbound network ACLs"
  type        = list(map(string))

  default = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
  ]
}
variable "custom_outbound_acl_rules" {
  description = "Custom subnets outbound network ACLs"
  type        = list(map(string))

  default = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
  ]
}
variable "public_subnet_tags" {
  type        = map(string)
  default     = { "Name" = "Public Subnet" }
  description = "Public Subnet Tags"
}
variable "private_subnet_tags" {
  type        = map(string)
  default     = { "Name" = "Private Subnet" }
  description = "Private Subnet Tags"
}
variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
  default     = false
}
