variable "aws_region" {
  description = "AWS Region containing the Transit Gateway and inspection VPC."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Three explicit AZs used for NAT, firewall, and TGW attachment subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) == 3 && length(distinct(var.availability_zones)) == 3
    error_message = "availability_zones must contain exactly three distinct AZs."
  }
}

variable "transit_gateway_id" {
  description = "Existing Transit Gateway used by the appliance-mode inspection attachment."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^tgw-[0-9a-f]{8,17}$", var.transit_gateway_id))
    error_message = "transit_gateway_id must be a valid Transit Gateway ID."
  }
}

variable "spoke_prefix_list_id" {
  description = "Customer-managed prefix list containing spoke destinations returned through the Transit Gateway."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^pl-[0-9a-f]{8,17}$", var.spoke_prefix_list_id))
    error_message = "spoke_prefix_list_id must be a valid managed prefix list ID."
  }
}

variable "spoke_network_cidr_blocks" {
  description = "Spoke address domains for the Network Firewall module's public-route-table return routes."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12"]

  validation {
    condition = (
      length(var.spoke_network_cidr_blocks) > 0 &&
      alltrue([for cidr in var.spoke_network_cidr_blocks : can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")])
    )
    error_message = "spoke_network_cidr_blocks must contain at least one valid IPv4 CIDR."
  }
}

variable "network_firewall_policy_arn" {
  description = "Firewall policy ARN required only when the documented aws-ia/networkfirewall/aws block is enabled."
  type        = string
  default     = null

  validation {
    condition = var.network_firewall_policy_arn == null || can(regex(
      "^arn:(aws|aws-us-gov|aws-cn):network-firewall:[a-z0-9-]+:[0-9]{12}:firewall-policy/.+$",
      var.network_firewall_policy_arn,
    ))
    error_message = "network_firewall_policy_arn must be null or a valid AWS Network Firewall policy ARN."
  }
}
