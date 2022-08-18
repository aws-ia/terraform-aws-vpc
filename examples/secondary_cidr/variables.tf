variable "vpc_id" {
  description = "vpc id to create secondary cidr on"
  type        = string
}

variable "natgw_id_per_az" {
  description = "use the modules natgw_id_per_az"
  type        = map(map(string))
}
