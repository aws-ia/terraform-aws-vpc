variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
  default     = true
}

variable "name" {
  type        = string
  description = "Will be used as a prefix for all resources that require a name field. Should be unique in the region."
  default     = null
  validation {
    condition     = can(length(var.name) < 223) || var.name == null
    error_message = "Name can not be longer than 222 characters."
  }
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
  validation {
    condition     = var.instance_tenancy == "default" || var.instance_tenancy == "dedicated"
    error_message = "Value must be either \"default\" or \"dedicated\"."
  }
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))?$", var.cidr)) && can(split("/", var.cidr)[1] >= 16) && can(split("/", var.cidr)[1] <= 28)
    error_message = "Value must be a valid cidr block and must have a subnet mask from 28 to 16. eg.: \"10.0.0.0/16\"."
  }
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks to use for public subnets. Default is 3 /20 cidrs from the CIDR range specified in the cidr variable. The number of public subnets is inferred from the number of CIDR's provided. The number of public subnets is inferred from the number of CIDR's provided. If availability_zones are specified, must have the same number of elements, if not specified number of elements must not be greater than the number of availability zones in the region."
  type        = list(string)
  default     = null
  validation {
    condition     = can([for s in var.public_subnet_cidrs : regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))?$", s)]) || var.public_subnet_cidrs == null
    error_message = "Each element of the list must be a valid CIDR block."
  }
}

variable "private_subnet_a_cidrs" {
  description = "A list of CIDR blocks to use for private subnets. Default is 3 /19 cidrs from the CIDR range specified in the cidr variable. The number of private subnets is inferred from the number of CIDR's provided. If availability_zones are specified, must have the same number of elements, if not specified number of elements must not be greater than the number of availability zones in the region."
  type        = list(string)
  default     = null
  validation {
    condition     = can([for s in var.private_subnet_a_cidrs : regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))?$", s)]) || var.private_subnet_a_cidrs == null
    error_message = "Each element of the list must be a valid CIDR block."
  }
}

variable "private_subnet_b_cidrs" {
  description = "A list of CIDR blocks to use for private subnets. Default is 3 /19 cidrs from the CIDR range specified in the cidr variable. The number of private subnets is inferred from the number of CIDR's provided."
  type        = list(string)
  default     = null
  validation {
    condition     = can([for s in var.private_subnet_b_cidrs : regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))?$", s)]) || var.private_subnet_b_cidrs == null
    error_message = "Each element of the list must be a valid CIDR block."
  }
}

variable "public_inbound_acl_rules" {
  description = "Public subnets inbound network ACLs. Default allows all traffic"
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
  description = "Public subnets outbound network ACLs. Default allows all traffic"
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

variable "private_a_inbound_acl_rules" {
  description = "Private subnet A's inbound network ACLs. Default allows all traffic"
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

variable "private_a_outbound_acl_rules" {
  description = "Private subnet A's outbound network ACLs. Default allows all traffic"
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

variable "private_b_inbound_acl_rules" {
  description = "Private subnet B's inbound network ACLs. Default allows all traffic"
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

variable "private_b_outbound_acl_rules" {
  description = "Private subnet B's outbound network ACLs. Default allows all traffic"
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

variable "availability_zones" {
  description = "A list of availability zones to use for subnets. If this is not provided availability zones for subnets will be automatically selected"
  type        = list(string)
  default     = null
}

variable "create_igw" {
  description = "If set to false no IGW will be created for the public subnets"
  type        = bool
  default     = true
}

variable "create_nat_gateways_private_a" {
  description = "If set to false no NATE gateways will be created for the private_a subnets"
  type        = bool
  default     = true
}

variable "create_nat_gateways_private_b" {
  description = "If set to false no NATE gateways will be created for the private_b subnets"
  type        = bool
  default     = false
}
