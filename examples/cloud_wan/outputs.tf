
output "vpcs" {
  description = "VPCs created."
  value = {
    nvirginia = module.nvirginia_vpc.vpc_attributes.id
    ireland   = module.ireland_vpc.vpc_attributes.id
  }
}

output "global_network" {
  description = "Global Network ID."
  value       = aws_networkmanager_global_network.global_network.id
}

output "core_network" {
  description = "Core Network ID."
  value       = aws_networkmanager_core_network.core_network.id
}

output "core_network_vpc_attachments" {
  description = "Core Network VPC attachments."
  value = {
    nvirginia = module.nvirginia_vpc.core_network_attachment.id
    ireland   = module.ireland_vpc.core_network_attachment.id
  }
}