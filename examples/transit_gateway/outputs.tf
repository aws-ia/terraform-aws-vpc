## Used for Testing, do not delete

output "tgw_subnets_tags_length" {
  description = "Count of tgw subnet tags for a single az."
  value       = try(length(module.vpc.tgw_subnet_attributes_by_az[data.aws_availability_zones.current.names[0]].tags), null)
}

output "private_subnets_tags_length" {
  description = "Count of private subnet tags for a single az."
  value       = try(length(module.vpc.private_subnet_attributes_by_az["private_dualstack/${data.aws_availability_zones.current.names[0]}"].tags), null)
}
