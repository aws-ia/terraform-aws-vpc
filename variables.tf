variable "name" {
  type        = string
  description = "Name to give VPC. Note: does not effect subnet names, which get assigned name based on name_prefix."
}

variable "vpc_cidr_block" {
  description = "CIDR range to assign to VPC if creating VPC. Overridden by var.vpc_id output from data.aws_vpc."
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
  description = "Configuration of subnets to build in VPC. Valid key restriction information found in variables.tf."
  type        = any

  ######### EXAMPLE #########
  #  subnets = {
  #   public = {
  #     name_prefix               = "my-public" # omit to prefix with "public"
  #     netmask                   = 24
  #     nat_gateway_configuration = "all_azs" # options: "single_az", "none"
  #     tags = { env = "dev" }
  #   }

  #   private = {
  #     name_prefix  = "private"
  #     netmask      = 24
  #     route_to_nat = true
  #   }
  # }
  ###########################

  # Only valid keys for var.subnets
  validation {
    error_message = "Only valid key values \"public\", \"private\"."
    condition = length(setsubtract(keys(var.subnets), [
      "public",
      "private"
    ])) == 0
  }

  # All var.subnets.public valid keys
  validation {
    error_message = "Invalid key in public subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"nat_gateway_configuration\", \"tags\"."
    condition = length(setsubtract(keys(try(var.subnets.public, {})), [
      "cidrs",
      "netmask",
      "name_prefix",
      "nat_gateway_configuration",
      "tags"
    ])) == 0
  }

  # All var.subnets.private valid keys
  validation {
    error_message = "Invalid key in private subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"route_to_nat\", \"tags\"."
    condition = length(setsubtract(keys(try(var.subnets.private, {})), [
      "cidrs",
      "netmask",
      "name_prefix",
      "route_to_nat",
      "tags"
    ])) == 0
  }

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
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_flow_logs" {
  description = "Whether or not to create VPC flow logs and which type. Options: \"cloudwatch\", \"s3\", \"none\". By default creates flow logs to `cloudwatch`. Variable overrides null value types for some keys, defined in defaults.tf."
  nullable    = false

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
