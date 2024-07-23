variable "name" {
  type        = string
  description = "Name to give VPC. Note: does not effect subnet names, which get assigned name based on name_prefix."
}

variable "cidr_block" {
  description = "IPv4 CIDR range to assign to VPC if creating VPC or to associate as a secondary IPv6 CIDR. Overridden by var.vpc_id output from data.aws_vpc."
  default     = null
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to use if not creating VPC."
  default     = null
  type        = string
}

variable "create_vpc" {
  description = "Determines whether to create the VPC or not; defaults to enabling the creation."
  default     = true
  type        = bool
}

variable "az_count" {
  type        = number
  default     = 0
  description = "Searches region for # of AZs to use and takes a slice based on count. Assume slice is sorted a-z."
}

variable "azs" {
  description = "A list of availability zones names"
  type        = list(string)
  default     = []
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

variable "vpc_secondary_cidr_natgw" {
  type        = any
  description = "If attaching a secondary IPv4 CIDR instead of creating a VPC, you can map private/ tgw subnets to your public NAT GW with this argument. Simply pass the output `nat_gateway_attributes_by_az`, ex: `vpc_secondary_cidr_natgw = module.vpc.natgw_id_per_az`. If you did not build your primary with this module, you must construct a map { az : { id : nat-123asdb }} for each az."
  default     = {}
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
}

variable "vpc_ipv4_ipam_pool_id" {
  description = "Set to use IPAM to get an IPv4 CIDR block."
  type        = string
  default     = null
}

variable "vpc_ipv4_netmask_length" {
  description = "Set to use IPAM to get an IPv4 CIDR block using a specified netmask. Must be set with var.vpc_ipv4_ipam_pool_id."
  type        = string
  default     = null
}

variable "vpc_assign_generated_ipv6_cidr_block" {
  description = "Requests and Amazon-provided IPv6 CIDR block with a /56 prefix length. You cannot specify the range of IP addresses, or the size of the CIDR block. Conflicts with `vpc_ipv6_ipam_pool_id`."
  type        = bool
  default     = null
}

variable "vpc_ipv6_ipam_pool_id" {
  description = "Set to use IPAM to get an IPv6 CIDR block."
  type        = string
  default     = null
}

variable "vpc_ipv6_cidr_block" {
  description = "IPv6 CIDR range to assign to VPC if creating VPC. You need to use `vpc_ipv6_ipam_pool_id` and set explicitly the CIDR block to use, or derived from IPAM using using `vpc_ipv6_netmask_length`."
  type        = string
  default     = null
}

variable "vpc_ipv6_netmask_length" {
  description = "Set to use IPAM to get an IPv6 CIDR block using a specified netmask. Must be set with `var.vpc_ipv6_ipam_pool_id`."
  type        = string
  default     = null
}

variable "vpc_egress_only_internet_gateway" {
  description = "Set to use the Egress-only Internet gateway for all IPv6 traffic going to the Internet."
  type        = bool
  default     = false
}

variable "subnets" {
  description = <<-EOF
  Configuration of subnets to build in VPC. 1 Subnet per AZ is created. Subnet types are defined as maps with the available keys: "private", "public", "transit_gateway", "core_network". Each Subnet type offers its own set of available arguments detailed below. Subnets are calculated in lexicographical order of the keys in the map.

  **Attributes shared across subnet types:**
  - `cidrs`            = (Optional|list(string)) **Cannot set if `netmask` is set.** List of IPv4 CIDRs to set to subnets. Count of CIDRs defined must match quantity of azs in `az_count`.
  - `netmask`          = (Optional|Int) **Cannot set if `cidrs` is set.** Netmask of the `var.cidr_block` to calculate for each subnet.
  - `assign_ipv6_cidr` = (Optional|bool) **Cannot set if `ipv6_cidrs` is set.** If true, it will calculate a /64 block from the IPv6 VPC CIDR to set in the subnets.
  - `ipv6_cidrs`       = (Optional|list(string)) **Cannot set if `assign_ipv6_cidr` is set.** List of IPv6 CIDRs to set to subnets. The subnet size must use a /64 prefix length. Count of CIDRs defined must match quantity of azs in `az_count`.
  - `name_prefix`      = (Optional|String) A string prefix to use for the name of your subnet and associated resources. Subnet type key name is used if omitted (aka private, public, transit_gateway). Example `name_prefix = "private"` for `var.subnets.private` is redundant.
  - `tags`             = (Optional|map(string)) Tags to set on the subnet and associated resources.

  **Any private subnet type options:**
  - All shared keys above
  - `connect_to_public_natgw` = (Optional|bool) Determines if routes to NAT Gateways should be created. Must also set `var.subnets.public.nat_gateway_configuration` in public subnets.
  - `ipv6_native`             = (Optional|bool) Indicates whether to create an IPv6-ony subnet. Either `var.assign_ipv6_cidr` or `var.ipv6_cidrs` should be defined to allocate an IPv6 CIDR block.
  - `connect_to_eigw`         = (Optional|bool) Determines if routes to the Egress-only Internet gateway should be created. Must also set `var.vpc_egress_only_internet_gateway`.

  **public subnet type options:**
  - All shared keys above
  - `nat_gateway_configuration` = (Optional|string) Determines if NAT Gateways should be created and in how many AZs. Valid values = `"none"`, `"single_az"`, `"all_azs"`. Default = "none". Must also set `var.subnets.private.connect_to_public_natgw = true`.
  - `connect_to_igw`            = (Optional|bool) Determines if the default route (0.0.0.0/0 or ::/0) is created in the public subnets with destination the Internet gateway. Defaults to `true`.
  - `ipv6_native`               = (Optional|bool) Indicates whether to create an IPv6-ony subnet. Either `var.assign_ipv6_cidr` or `var.ipv6_cidrs` should be defined to allocate an IPv6 CIDR block.
  - `map_public_ip_on_launch`   = (Optional|bool) Specify true to indicate that instances launched into the subnet should be assigned a public IP address. Default to `false`.

  **transit_gateway subnet type options:**
  - All shared keys above
  - `connect_to_public_natgw`                         = (Optional|string) Determines if routes to NAT Gateways should be created. Specify the CIDR range or a prefix-list-id that you want routed to nat gateway. Usually `0.0.0.0/0`. Must also set `var.subnets.public.nat_gateway_configuration`.
  - `transit_gateway_default_route_table_association` = (Optional|bool) Boolean whether the VPC Attachment should be associated with the EC2 Transit Gateway association default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.
  - `transit_gateway_default_route_table_propagation` = (Optional|bool) Boolean whether the VPC Attachment should propagate routes with the EC2 Transit Gateway propagation default route table. This cannot be configured or perform drift detection with Resource Access Manager shared EC2 Transit Gateways.
  - `transit_gateway_appliance_mode_support`          = (Optional|string) Whether Appliance Mode is enabled. If enabled, a traffic flow between a source and a destination uses the same Availability Zone for the VPC attachment for the lifetime of that flow. Valid values: `disable` (default) and `enable`.
  - `transit_gateway_dns_support`                     = (Optional|string) DNS Support is used if you need the VPC to resolve public IPv4 DNS host names to private IPv4 addresses when queried from instances in another VPC attached to the transit gateway. Valid values: `enable` (default) and `disable`.

  **core_network subnet type options:**
  - All shared keys abovce
  - `connect_to_public_natgw` = (Optional|string) Determines if routes to NAT Gateways should be created. Specify the CIDR range or a prefix-list-id that you want routed to nat gateway. Usually `0.0.0.0/0`. Must also set `var.subnets.public.nat_gateway_configuration`.
  - `appliance_mode_support`  = (Optional|bool) Indicates whether appliance mode is supported. If enabled, traffic flow between a source and destination use the same Availability Zone for the VPC attachment for the lifetime of that flow. Defaults to `false`.
  - `require_acceptance`      = (Optional|bool) Boolean whether the core network VPC attachment to create requires acceptance or not. Defaults to `false`.
  - `accept_attachment`       = (Optional|bool) Boolean whether the core network VPC attachment is accepted or not in the segment. Only valid if `require_acceptance` is set to `true`. Defaults to `true`.

  Example:
  ```
  subnets = {
    # Dual-stack subnet
    public = {
      netmask                   = 24
      assign_ipv6_cidr          = true
      nat_gateway_configuration = "single_az"
    }
    # IPv4 only subnet
    private = {
      netmask                  = 24
      connect_to_public_natgw  = true
    }
    # IPv6 only subnet
    ipv6 = {
      ipv6_native      = true
      assign_ipv6_cidr = true
      connect_to_eigw  = true
    }
    # Transit gateway subnets (dual-stack)
    transit_gateway = {
      netmask                                         = 24
      assign_ipv6_cidr                                = true
      connect_to_public_natgw                         = true
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
    }
    # Core Network subnets (dual-stack)
    core_network = {
      netmask                 = 24
      assign_ipv6_cidr        = true
      connect_to_public_natgw = true
      appliance_mode_support  = true
      require_acceptance      = true
      accept_attachment       = true
    }
  }
  ```
EOF
  type        = any

  # All var.subnets.public valid keys
  validation {
    error_message = "Invalid key in public subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"connect_to_igw\", \"nat_gateway_configuration\", \"ipv6_native\", \"assign_ipv6_cidr\", \"ipv6_cidrs\", \"tags\"."
    condition = length(setsubtract(keys(try(var.subnets.public, {})), [
      "cidrs",
      "netmask",
      "name_prefix",
      "connect_to_igw",
      "nat_gateway_configuration",
      "ipv6_native",
      "assign_ipv6_cidr",
      "ipv6_cidrs",
      "map_public_ip_on_launch",
      "tags"
    ])) == 0
  }

  # All var.subnets.transit_gateway valid keys
  validation {
    error_message = "Invalid key in transit_gateway subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"connect_to_public_natgw\", \"assign_ipv6_cidr\", \"ipv6_cidrs\", \"transit_gateway_default_route_table_association\", \"transit_gateway_default_route_table_propagation\", \"transit_gateway_appliance_mode_support\", \"transit_gateway_dns_support\", \"tags\"."
    condition = length(setsubtract(keys(try(var.subnets.transit_gateway, {})), [
      "cidrs",
      "netmask",
      "name_prefix",
      "connect_to_public_natgw",
      "assign_ipv6_cidr",
      "ipv6_cidrs",
      "transit_gateway_default_route_table_association",
      "transit_gateway_default_route_table_propagation",
      "transit_gateway_appliance_mode_support",
      "transit_gateway_dns_support",
      "tags"
    ])) == 0
  }

  # All var.subnets.core_network valid keys
  validation {
    error_message = "Invalid key in core_network subnets. Valid options include: \"cidrs\", \"netmask\", \"name_prefix\", \"connect_to_public_natgw\", \"assign_ipv6_cidr\", \"ipv6_cidrs\", \"appliance_mode_support\", \"require_acceptance\", \"accept_attachment\", \"tags\"."
    condition = length(setsubtract(keys(try(var.subnets.core_network, {})), [
      "cidrs",
      "netmask",
      "name_prefix",
      "connect_to_public_natgw",
      "assign_ipv6_cidr",
      "ipv6_cidrs",
      "appliance_mode_support",
      "require_acceptance",
      "accept_attachment",
      "tags"
    ])) == 0
  }

  validation {
    error_message = "Each subnet type must contain only 1 key: `cidrs` or `netmask` or `ipv6_native`."
    condition     = alltrue([for subnet_type, v in var.subnets : length(setintersection(keys(v), ["cidrs", "netmask", "ipv6_native"])) == 1])
  }

  validation {
    error_message = "Public subnet `nat_gateway_configuration` can only be `all_azs`, `single_az`, `none`, or `null`."
    condition     = can(regex("^(all_azs|single_az|none)$", var.subnets.public.nat_gateway_configuration)) || try(var.subnets.public.nat_gateway_configuration, null) == null
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

  type = object({
    name_override   = optional(string, "")
    log_destination = optional(string)
    iam_role_arn    = optional(string)
    kms_key_id      = optional(string)

    log_destination_type = string
    retention_in_days    = optional(number)
    tags                 = optional(map(string))
    traffic_type         = optional(string, "ALL")
    destination_options = optional(object({
      file_format                = optional(string, "plain-text")
      hive_compatible_partitions = optional(bool, false)
      per_hour_partition         = optional(bool, false)
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

variable "transit_gateway_id" {
  type        = string
  description = "Transit gateway id to attach the VPC to. Required when `transit_gateway` subnet is defined."
  default     = null
}

variable "transit_gateway_routes" {
  description = <<-EOF
  Configuration of route(s) to transit gateway.
  For each `public` and/or `private` subnets named in the `subnets` variable,
  Optionally create routes from the subnet to transit gateway. Specify the CIDR range or a prefix-list-id that you want routed to the transit gateway.
  Example:
  ```
  transit_gateway_routes = {
    public  = "10.0.0.0/8"
    private = "pl-123"
  }
  ```
EOF
  type        = any
  default     = {}
}

variable "transit_gateway_ipv6_routes" {
  description = <<-EOF
  Configuration of IPv6 route(s) to transit gateway.
  For each `public` and/or `private` subnets named in the `subnets` variable,
  Optionally create routes from the subnet to transit gateway. Specify the CIDR range or a prefix-list-id that you want routed to the transit gateway.
  Example:
  ```
  transit_gateway_ipv6_routes = {
    public  = "::/0"
    private = "pl-123"
  }
  ```
EOF
  type        = any
  default     = {}
}

variable "core_network" {
  type = object({
    id  = string
    arn = string
  })
  description = "AWS Cloud WAN's core network information - to create a VPC attachment. Required when `cloud_wan` subnet is defined. Two attributes are required: the `id` and `arn` of the resource."

  default = {
    id  = null
    arn = null
  }
}

variable "core_network_routes" {
  description = <<-EOF
  Configuration of route(s) to AWS Cloud WAN's core network.
  For each `public` and/or `private` subnets named in the `subnets` variable, optionally create routes from the subnet to the core network.
  You can specify either a CIDR range or a prefix-list-id that you want routed to the core network.
  Example:
  ```
  core_network_routes = {
    public  = "10.0.0.0/8"
    private = "pl-123"
  }
  ```
EOF
  type        = any
  default     = {}
}

variable "core_network_ipv6_routes" {
  description = <<-EOF
  Configuration of IPv6 route(s) to AWS Cloud WAN's core network.
  For each `public` and/or `private` subnets named in the `subnets` variable, optionally create routes from the subnet to the core network.
  You can specify either a CIDR range or a prefix-list-id that you want routed to the core network.
  Example:
  ```
  core_network_ivp6_routes = {
    public  = "::/0"
    private = "pl-123"
  }
  ```
EOF
  type        = any
  default     = {}
}

variable "vpc_lattice" {
  description = <<-EOF
  Amazon VPC Lattice Service Network VPC association. You can only associate one Service Network to the VPC. This association also support Security Groups (more than 1).
  This variable expects the following attributes:
  - `service_network_identifier` = (Required|string) The ID or ARN of the Service Network to associate. You must use the ARN if the Service Network and VPC resources are in different AWS Accounts.
  - `security_group_ids`         = (Optional|list(string)) The IDs of the security groups to attach to the association.
  - `tags`                       = (Optional|map(string)) Tags to set on the Lattice VPC association resource.
EOF
  type        = any

  default = {}

  # All var.vpc_lattice valid keys
  validation {
    error_message = "Invalid key in var.vpc_lattice. Valid options include: \"service_network_identifier\", \"security_group_ids\", \"tags\"."
    condition = length(setsubtract(keys(var.vpc_lattice), [
      "service_network_identifier",
      "security_group_ids",
      "tags"
    ])) == 0
  }
}
