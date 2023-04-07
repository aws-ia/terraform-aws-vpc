
variable "aws_region" {
  description = "AWS Regions to create in Cloud WAN's core network."
  type        = string

  default = "eu-west-2"
}

variable "prefixes" {
  type        = map(string)
  description = "(optional) describe your variable"

  default = {
    primary  = "10.0.0.0/8",
    internal = "192.168.0.0/16"
  }
}