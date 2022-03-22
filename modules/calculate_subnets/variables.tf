variable "subnets" {
  description = "Defition of subnets to be built. If `netmask` is passed will calculate CIDR. Else `cidrs` list is ziped to var.azs and merged into final output to be built into aws_subnet(s)."
  type        = any
  # validation happening on root module
}
variable "azs" {
  description = "List of AZs to build. AZ is appened to each IP address prefix name."
  type        = list(string)
}

variable "cidr" {
  description = "CIDR value to use as base for calculating IP address prefixes."
  type        = string
}
