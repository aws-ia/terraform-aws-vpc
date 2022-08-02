variable "tgw_id" {
  type        = string
  description = "(required) Transit Gateway ID."
}

variable "subnets" {
  type        = any
  description = "(optional) describe your variable"
  default     = {}
}
