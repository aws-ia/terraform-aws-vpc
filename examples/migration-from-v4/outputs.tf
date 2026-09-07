output "vpc_id" {
  description = "ID of the migrated VPC."
  value       = module.vpc.vpc_id
}

output "subnet_ids_by_group_by_az" {
  description = "Tier 1 subnet IDs by v4-preserved group key and Availability Zone."
  value       = module.vpc.subnet_ids_by_group_by_az
}

output "v4_private_subnet_attributes_by_az" {
  description = "Deprecated Tier 2 compatibility alias retained while downstream consumers migrate."
  value       = module.vpc.private_subnet_attributes_by_az
}

output "v4_name_compatibility" {
  description = "Representative Name tags that must remain identical during v4 migration."
  value = {
    public_subnet      = module.vpc.resources.subnets["public/us-east-1a"].tags.Name
    app_route_table    = module.vpc.resources.route_tables["app/us-east-1a"].tags.Name
    nat_eip            = module.vpc.resources.eips["nat/us-east-1a"].tags.Name
    nat_gateway        = module.vpc.resources.nat_gateways["nat/us-east-1a"].tags.Name
    internet_gateway   = module.vpc.resources.internet_gateway[0].tags.Name
    egress_only_igw    = module.vpc.resources.egress_only_internet_gateway[0].tags.Name
    flow_log           = module.vpc.resources.flow_logs["default"].tags.Name
    log_group_has_name = contains(keys(module.vpc.resources.flow_log_destinations["default"].tags), "Name")
  }
}


output "default_resource_management" {
  description = "Default IDs are always available while default-resource hardening remains opt-in and absent from the v4 migration plan."
  value = {
    ids                  = module.vpc.default_resource_ids
    security_group_count = length(module.vpc.resources.default_resources.security_groups)
    network_acl_count    = length(module.vpc.resources.default_resources.network_acls)
    route_table_count    = length(module.vpc.resources.default_resources.route_tables)
  }
}
