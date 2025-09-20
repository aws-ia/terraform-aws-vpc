output "vpc_id" {
  description = "vpc id"
  value       = module.vpc.vpc_attributes.id

}

output "natgw_ids" {
  value       = module.vpc.natgw_id_per_az
  description = "nat gateway ids per az"
}

