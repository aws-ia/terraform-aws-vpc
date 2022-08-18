variable "nat_gw_configuration" {
  type        = string
  default     = "all_azs"
  description = <<-EOF
    If referencing another instantiation of this module, you can use the output natgw_id_per_az, example:
    vpc_secondary_cidr_natgw = module.vpc.natgw_id_per_az

    underly structure is:
    {
        az : {
            id : "nat-asdf"
        }
    }
    but preferably you should just pass the module output natgw_id_per_az
EOF
}

