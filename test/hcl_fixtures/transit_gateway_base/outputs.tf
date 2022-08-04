output "tgw_id" {
  description = "aws_ec2_transit_gateway ID."
  value       = aws_ec2_transit_gateway.example.id
}

output "prefix_list_id" {
  description = "aws_ec2_managed_prefix_list ID."
  value       = aws_ec2_managed_prefix_list.example.id
}
