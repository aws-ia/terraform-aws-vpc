variable "vpc_id" {
  description = "vpc id to create secondary cidr on"
  type        = string
}

variable "natgw_id_1" {
  description = "nat gw id for az 2"
  type        = string
}

variable "natgw_id_2" {
  description = "nat gw id for az 2"
  type        = string
}
