# ---------------------------------------------------------------------------------------------------------------------
# PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------
variable "region" {
  type        = string
  description = "The name of the region you wish to deploy into"
  default     = "us-east-1"
}

variable "name" {
  description = "Name given resources"
  type        = string
  default     = "aws-quickstart"
}

variable "create_bastion" {
  description = "Create resource"
  type        = bool
  default     = true
}

variable "key_name" {
  type = string
  description = "ssh key name"
}