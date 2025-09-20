variable "vpc_id" {
  description = "vpc id to create secondary cidr on"
  type        = string
  default     = null
}

variable "natgw_id_per_az" {
  description = "use the modules natgw_id_per_az"
  type        = map(map(string))
  default     = null
}

variable "az_count" {
  description = "az count"
  default     = 1
  type        = number
}
