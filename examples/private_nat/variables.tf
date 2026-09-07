variable "aws_region" {
  description = "AWS Region containing the Transit Gateway."
  type        = string
  default     = "us-west-2"
}

variable "availability_zones" {
  description = "Two explicit AZs used for workloads, private NAT, and TGW attachment subnets."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct AZs."
  }
}

variable "transit_gateway_id" {
  description = "Existing Transit Gateway that routes translated traffic toward the overlapping address domain."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^tgw-[0-9a-f]{8,17}$", var.transit_gateway_id))
    error_message = "transit_gateway_id must be a valid Transit Gateway ID."
  }
}

variable "tgw_destination_cidrs" {
  description = "Remote 10/8 segments routed from the private NAT subnets to the Transit Gateway."
  type        = list(string)
  default     = ["10.100.0.0/16", "10.200.0.0/16"]

  validation {
    condition = (
      length(var.tgw_destination_cidrs) > 0 &&
      alltrue([for cidr in var.tgw_destination_cidrs : can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")])
    )
    error_message = "tgw_destination_cidrs must contain at least one valid IPv4 CIDR."
  }
}
