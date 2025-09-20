variable "nat_gw_configuration" {
  type        = string
  default     = "all_azs"
  description = "value to pass to nat_gateway_configuration"
}

variable "az_count" {
  description = "az count"
  default     = 1
  type        = number
}
