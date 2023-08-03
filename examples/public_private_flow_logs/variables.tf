variable "aws_region" {
  description = "AWS Region."
  type        = string
  default     = "eu-west-1"
}

variable "subnets" {
  default = null
}
variable "az_count" {
  default = null
}
variable "name" {
  default = null
}
