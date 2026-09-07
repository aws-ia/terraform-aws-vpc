variable "aws_region" {
  description = "AWS Region containing the hub dependencies."
  type        = string
  default     = "us-west-2"
}

variable "transit_gateway_ids" {
  description = "Distinct Transit Gateway IDs keyed by stable east and west attachment identities."
  type        = map(string)
  nullable    = false

  validation {
    condition = (
      toset(keys(var.transit_gateway_ids)) == toset(["east", "west"]) &&
      length(distinct(values(var.transit_gateway_ids))) == 2 &&
      alltrue([for id in values(var.transit_gateway_ids) : can(regex("^tgw-[0-9a-f]{8,17}$", id))])
    )
    error_message = "transit_gateway_ids must contain distinct valid Transit Gateway IDs under exactly the keys east and west."
  }
}

variable "gwlb_endpoint_ids_by_az" {
  description = "Existing GWLB endpoint IDs targeted by the hub's late-bound route, keyed by Availability Zone."
  type        = map(string)
  nullable    = false

  validation {
    condition = (
      toset(keys(var.gwlb_endpoint_ids_by_az)) == toset(["us-west-2a", "us-west-2b", "us-west-2c"]) &&
      alltrue([for id in values(var.gwlb_endpoint_ids_by_az) : can(regex("^vpce-[0-9a-f]{8,17}$", id))])
    )
    error_message = "gwlb_endpoint_ids_by_az must contain valid VPC endpoint IDs for us-west-2a, us-west-2b, and us-west-2c."
  }
}

variable "vpc_peering_connection_id" {
  description = "Existing VPC peering connection targeted by the generic security-services route."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^pcx-[0-9a-f]{8,17}$", var.vpc_peering_connection_id))
    error_message = "vpc_peering_connection_id must be a valid VPC peering connection ID."
  }
}

variable "core_network_id" {
  description = "Cloud WAN Core Network ID used by the hub attachment."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^cnet-[0-9a-f]{8,17}$", var.core_network_id))
    error_message = "core_network_id must be a valid Core Network ID."
  }
}

variable "core_network_arn" {
  description = "Cloud WAN Core Network ARN matching core_network_id."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov|aws-cn):networkmanager::[0-9]{12}:core-network/cnet-[0-9a-f]{8,17}$", var.core_network_arn))
    error_message = "core_network_arn must be a valid Cloud WAN Core Network ARN."
  }
}

variable "nat_eip_allocation_ids" {
  description = "Existing EIP allocation IDs for the three hub NAT Gateways, keyed by AZ."
  type        = map(string)
  nullable    = false

  validation {
    condition = (
      toset(keys(var.nat_eip_allocation_ids)) == toset(["us-west-2a", "us-west-2b", "us-west-2c"]) &&
      alltrue([for id in values(var.nat_eip_allocation_ids) : can(regex("^eipalloc-[0-9a-f]{8,17}$", id))])
    )
    error_message = "nat_eip_allocation_ids must contain valid EIP allocation IDs for us-west-2a, us-west-2b, and us-west-2c."
  }
}

variable "flow_log_destination_arn" {
  description = "Existing Kinesis Data Firehose delivery stream ARN for VPC Flow Logs."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov|aws-cn):firehose:[a-z0-9-]+:[0-9]{12}:deliverystream/.+$", var.flow_log_destination_arn))
    error_message = "flow_log_destination_arn must be a valid Kinesis Data Firehose delivery stream ARN."
  }
}
