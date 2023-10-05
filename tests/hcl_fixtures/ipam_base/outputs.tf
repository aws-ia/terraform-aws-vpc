output "pool_id" {
  description = "Pool ID."
  value       = module.ipam.pools_level_1[data.aws_region.current.name].id
}
