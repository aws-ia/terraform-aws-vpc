variable "nat_gateway_configuration" {
  description = "all_azs, single_az, or none"
  type        = string
}

variable "route_to_nw" {
  description = "Tags for the public subnets"
  type        = bool
}
