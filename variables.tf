variable "name" {
  type        = string
  description = "Name to give VPC. Note: does not effect subnet names, which get assigned name based on name_prefix."
}

variable "cidr_block" {
  description = "CIDR range to assign to VPC if creating VPC or to associte as a secondary CIDR. Overridden by var.vpc_id output from data.aws_vpc."
  default     = null
  type        = string

}

variable "vpc_id" {
  description = "VPC ID to use if not creating VPC."
  default     = null
  type        = string
}

variable "az_count" {
  type        = number
  description = "Searches region for # of AZs to use and takes a slice based on count. Assume slice is sorted a-z."
}

variable "vpc_enable_dns_hostnames" {
  type        = bool
  description = "Indicates whether the instances launched in the VPC get DNS hostnames. If enabled, instances in the VPC get DNS hostnames; otherwise, they do not. Disabled by default for nondefault VPCs."
  default     = true
}

variable "vpc_secondary_cidr" {
  type        = bool
  description = "If `true` the module will create a `aws_vpc_ipv4_cidr_block_association` and subnets for that secondary cidr. If using IPAM for both primary and secondary CIDRs, you may only call this module serially (aka using `-target`, etc)."
  default     = false
}

variable "vpc_enable_dns_support" {
  type        = bool
  description = "Indicates whether the DNS resolution is supported for the VPC. If enabled, queries to the Amazon provided DNS server at the 169.254.169.253 IP address, or the reserved IP address at the base of the VPC network range \"plus two\" succeed. If disabled, the Amazon provided DNS service in the VPC that resolves public DNS hostnames to IP addresses is not enabled. Enabled by default."
  default     = true
}

variable "vpc_instance_tenancy" {
  type        = string
  description = "The allowed tenancy of instances launched into the VPC."
  default     = "default"

  /*
  Note:
  Updating InstanceTenancy requires no replacement only if you are updating its value from "dedicated" to "default". Updating InstanceTenancy from "default" to "dedicated" requires replacement.
  */

  validation {
    condition     = var.vpc_instance_tenancy == "default" || var.vpc_instance_tenancy == "dedicated"
    error_message = "Invalid input, options: \"default\", or \"dedicated\"."
  }
}

variable "vpc_ipv4_ipam_pool_id" {
  description = "Set to use IPAM to get CIDR block."
  type        = string
  default     = null
}

variable "vpc_ipv4_netmask_length" {
  description = "Set to use IPAM to get CIDR block using a specified netmask. Must be set with var.vpc_ipv4_ipam_pool_id."
  type        = string
  default     = null
}

variable "subnets" {
  description = <<-EOF
  Configuration of subnets to build in VPC. 1 Subnet per AZ is created. Subnet types are defined as maps with the available keys: "private", "public", "transit_gateway". Each Subnet type offers its own set of available arguments detailed below.

  **Attributes shared across subnet types:**
  - `cidrs`       = (Optional|list(string)) **Cannot set if `netmask` is set.** List of CIDRs to set to subnets. Count of CIDRs defined must match quatity of azs in `az_count`.
  - `netmask`     = (Optional|Int) Netmask of the `var.cidr_block` to calculate for each subnet. **Cannot set if `cidrs` is set.**
  - `name_prefix` = (Optional|String) A string prefix to use for the name of your subnet and associated resources. Subnet type key name is used if omitted (aka private, public, transit_gateway). Example `name_prefix = "private"` for `var.subnets.private` is redundant.
  - `tags`        = (Optional|map(string)) Tags to set on the subnet and associated resources.

  **private subnet type options:**
  - All shared keys above
  - `route_to_nat`             = (Optional|bool) Determines if routes to NAT Gateways should be created. Default = false. Must also set `var.subnets.public.nat_gateway_configuration`.
  - `route_to_transit_gateway` = (Optional|list(string)) Optionally create routes from private subnets to transit gateway subnets.

  **public subnet type options:**
  - All shared keys above
  - `nat_gateway_configuration` = (Optional|string) Determines if NAT Gateways should be created and in how many AZs. Valid values = `"none"`, `"single_az"`, `"all_azs"`. Default = "none". Must also set `var.subnets.private.route_to_nat = true`.
  - `route_to_transit_gateway`  = (Optional|list(string)) Optionally create routes from private subnets to transit gateway subnets.

  **transit_gateway subnet type options:**
  - All shared keys above
  - `route_to_nat`                                    = (Optional|bool) Determines if routes to NAT Gateways should be created. Default = false. Must also set `var.subnets.public.nat_gateway_configuration`.
  - `transit_gateway_id`                              = (Required|string) Transit gateway to attach VPC to.
  - `transit_gateway_default_route_table_association` = (Optional|bool) Boolean whether the VPC Attachment should be associated with the EC2 Transit Gateway association default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.
  - `transit_gateway_default_route_table_propagation` = (Optional|bool) Boolean whether the VPC Attachment should propagate routes with the EC2 Transit Gateway propagation default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.
  - `transit_gateway_appliance_mode_support`          = (Optional|string) Whether Appliance Mode is enabled. If enabled, a traffic flow between a source and a destination uses the same Availability Zone for the VPC attachment for the lifetime of that flow. Valid values: `disable` (default) and `enable`.
  - `transit_gateway_dns_support`                     = (Optional|string) DNS Support is used if you need the VPC to resolve public IPv4 DNS host names to private IPv4 addresses when queried from instances in another VPC attached to the transit gateway. Valid values: `enable` (default) and `disable`.

  Example:
  ```
  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "single_az"
      route_to_transit_gateway  = ["10.1.0.0/16"]
    }

    private = {
      netmask                  = 24
      route_to_nat             = true
      route_to_transit_gateway = ["10.1.0.0/16"]
    }

    transit_gateway = {
      netmask                                         = 24
      transit_gateway_id                              = aws_ec2_transit_gateway.example.id
      route_to_nat                                    = false
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
    }
  }
  ```
EOF
  type        = any

  # All var.subnets.public valid keys
  # validation {
  #   error_message = "Invalid key in public subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"nat_gateway_configuration\", \"tags\"."
  #   condition = length(setsubtract(keys(try(var.subnets.public, {})), [
  #     "cidrs",
  #     "netmask",
  #     "name_prefix",
  #     "nat_gateway_configuration",
  #     "route_to_transit_gateway",
  #     "tags"
  #   ])) == 0
  # }

  # # All var.subnets.private valid keys
  # validation {
  #   error_message = "Invalid key in private subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"route_to_nat\", \"tags\"."
  #   condition = length(setsubtract(keys(try(var.subnets.private, {})), [
  #     "cidrs",
  #     "netmask",
  #     "name_prefix",
  #     "route_to_nat",
  #     "route_to_transit_gateway",
  #     "tags"
  #   ])) == 0
  # }

  # # All var.subnets.transit_gateway valid keys
  # validation {
  #   error_message = "Invalid key in transit_gateway subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"transit_gateway_id\", \"transit_gateway_default_route_table_association\", \"transit_gateway_default_route_table_propagation\", \"transit_gateway_appliance_mode_support\", \"transit_gateway_dns_support\", \"tags\"."
  #   condition = length(setsubtract(keys(try(var.subnets.transit_gateway, {})), [
  #     "cidrs",
  #     "netmask",
  #     "name_prefix",
  #     "route_to_nat",
  #     "transit_gateway_id",
  #     "transit_gateway_default_route_table_association",
  #     "transit_gateway_default_route_table_propagation",
  #     "transit_gateway_appliance_mode_support",
  #     "transit_gateway_dns_support",
  #     "tags"
  #   ])) == 0
  # }

  validation {
    error_message = "Each subnet type must contain only 1 key: `cidrs` or `netmask`."
    condition     = alltrue([for subnet_type, v in var.subnets : length(setintersection(keys(v), ["cidrs", "netmask"])) == 1])
  }

  validation {
    error_message = "Public subnet `nat_gateway_configuration` can only be `all_azs`, `single_az`, `none`, or `null`."
    condition     = can(regex("^(all_azs|single_az|none)$", var.subnets.public.nat_gateway_configuration)) || try(var.subnets.public.nat_gateway_configuration, null) == null
  }

  validation {
    error_message = "If private.route_to_nat == true, then public.nat_gateway_configuration must be either `all_azs` or `single_az`."
    condition     = try(var.subnets.private.route_to_nat, false) ? can(regex("^(all_azs|single_az)$", var.subnets.public.nat_gateway_configuration)) : true
  }

  validation {
    error_message = "Any subnet type `name_prefix` must not contain \"/\"."
    condition     = alltrue([for _, v in var.subnets : !can(regex("/", try(v.name_prefix, "")))])
  }

  validation {
    error_message = "Private subnet cannot set `route_to_transit_gateway` = \"0.0.0.0/.\" if `route_to_nat` = true."
    condition     = try(var.subnets.private.route_to_nat, false) ? try(var.subnets.private.route_to_transit_gateway[0] != "0.0.0.0/0", true) : true
  }

  # TODO: remove once `route_to_transit_gateway` can accept more than 1 argument
  validation {
    error_message = "Argument `route_to_transit_gateway` cannot accept more than 1 string."
    condition     = try(length(var.subnets.private.route_to_transit_gateway), 0) <= 1 || try(length(var.subnets.public.route_to_transit_gateway), 0) <= 1
  }
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_flow_logs" {
  description = "Whether or not to create VPC flow logs and which type. Options: \"cloudwatch\", \"s3\", \"none\". By default creates flow logs to `cloudwatch`. Variable overrides null value types for some keys, defined in defaults.tf."

  type = object({
    log_destination = optional(string)
    iam_role_arn    = optional(string)
    kms_key_id      = optional(string)

    log_destination_type = string
    retention_in_days    = optional(number)
    tags                 = optional(map(string))
    traffic_type         = optional(string)
    destination_options = optional(object({
      file_format                = optional(string)
      hive_compatible_partitions = optional(bool)
      per_hour_partition         = optional(bool)
    }))
  })

  default = {
    log_destination_type = "none"
  }

  validation {
    condition     = contains(["cloud-watch-logs", "s3", "none"], var.vpc_flow_logs.log_destination_type)
    error_message = "Invalid input, options: \"cloud-watch-logs\", \"s3\", or \"none\"."
  }
}
