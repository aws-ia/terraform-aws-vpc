
variable "aws_region" {
  description = "AWS Region."
  type        = string

  default = "eu-west-1"
}

variable "prefixes" {
  type        = map(string)
  description = "IPv4 prefixes."

  default = {
    primary  = "10.0.0.0/8",
    internal = "192.168.0.0/16"
  }
}