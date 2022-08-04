variable "prefixes" {
  type        = map(string)
  description = "(optional) describe your variable"
  default = {
    primary  = "10.0.0.0/8",
    internal = "192.168.0.0/16"
  }
}
