output "pool_id" {
  description = "Pool ID."
  value       = module.ipam.pools_level_1["subpool"].id
}
