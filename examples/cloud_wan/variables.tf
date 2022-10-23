
variable "cloud_wan_regions" {
  description = "AWS Regions to create in Cloud WAN's core network."
  type = object({
    nvirginia = string
    ireland   = string
  })

  default = {
    nvirginia = "us-east-1"
    ireland   = "eu-west-1"
  }
}