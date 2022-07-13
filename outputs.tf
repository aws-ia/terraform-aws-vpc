output "vpc_attributes" {
  description = "VPC resource attributes. Full output of aws_vpc."
  value       = local.vpc
}

output "subnet_cidrs_by_type_by_az" {
  value       = module.calculate_subnets.subnets_by_type
  description = <<-EOF
  Map of subnets grouped by type with child map { az = cidr }.

  Example:
  ```
    subnets = {
      private = {
        us-east-1a = "10.0.0.0/24"
        us-east-1b = "10.0.1.0/24"
        us-east-1c = "10.0.2.0/24"
      }
      public  = {
        us-east-1a = "10.0.3.0/24"
        us-east-1b = "10.0.4.0/24"
        us-east-1c = "10.0.5.0/24"
      }
    }
  ```
EOF
}

output "transit_gateway_attachment_id" {
  description = "Transit gateway attachment id."
  value       = try(aws_ec2_transit_gateway_vpc_attachment.tgw[0].id, null)
}

output "multi_private_subnet_attributes_by_az" {
  value       = try(aws_subnet.private, null)
  description = <<-EOF
  Map of all private subnets containing their attributes.

  Example:
  ```
  private_subnet_attributes = {
    "private/us-east-1a" = {
      "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"
      "assign_ipv6_address_on_creation" = false
      ...
      <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference>
    }
    "us-east-1b" = {...)
  }
  ```
EOF
}

output "public_subnet_attributes_by_az" {
  value       = try(aws_subnet.public, null)
  description = <<-EOF
  Map of all public subnets containing their attributes.

  Example:
  ```
  public_subnet_attributes = {
    "us-east-1a" = {
      "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"
      "assign_ipv6_address_on_creation" = false
      ...
      <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference>
    }
    "us-east-1b" = {...)
  }
  ```
EOF
}

output "tgw_subnet_attributes_by_az" {
  value       = try(aws_subnet.tgw, null)
  description = <<-EOF
  Map of all tgw subnets containing their attributes.

  Example:
  ```
  tgw_subnet_attributes = {
    "us-east-1a" = {
      "arn" = "arn:aws:ec2:us-east-1:<>:subnet/subnet-04a86315c4839b519"
      "assign_ipv6_address_on_creation" = false
      ...
      <all attributes of subnet: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#attributes-reference>
    }
    "us-east-1b" = {...)
  }
  ```
EOF
}

output "rt_attributes_by_type_by_az" {
  value = {
    # TODO: omit keys if value is null
    "private"         = awscc_ec2_route_table.private,
    "public"          = awscc_ec2_route_table.public
    "transit_gateway" = awscc_ec2_route_table.tgw
  }
  description = <<-EOF
  Map of route tables by type => az => route table attributes. Example usage: module.vpc.route_table_by_subnet_type.private.id

  Example:
  ```
  route_table_attributes_by_type_by_az = {
    "private" = {
      "us-east-1a" = {
        "id" = "rtb-0e77040c0598df003"
        "route_table_id" = "rtb-0e77040c0598df003"
        "tags" = tolist([
          {
            "key" = "Name"
            "value" = "private-us-east-1a"
          },
        ])
        "vpc_id" = "vpc-033e054f49409592a"
      }
      "us-east-1b" = { ... }
    "public" = { ... }
  ```
EOF
}

output "nat_gateway_attributes_by_az" {
  value       = try(aws_nat_gateway.main, null)
  description = <<-EOF
  Map of nat gateway resource attributes by AZ.

  Example:
  ```
  nat_gateway_attributes_by_az = {
    "us-east-1a" = {
      "allocation_id" = "eipalloc-0e8b20303eea88b13"
      "connectivity_type" = "public"
      "id" = "nat-0fde39f9550f4abb5"
      "network_interface_id" = "eni-0d422727088bf9a86"
      "private_ip" = "10.0.3.40"
      "public_ip" = <>
      "subnet_id" = "subnet-0f11c92e439c8ab4a"
      "tags" = tomap({
        "Name" = "nat-my-public-us-east-1a"
      })
      "tags_all" = tomap({
        "Name" = "nat-my-public-us-east-1a"
      })
    }
    "us-east-1b" = { ... }
  }
  ```
EOF
}

## DEPRECATED OUTPUTS

output "subnets" {
  description = "DEPRECATED OUTPUT: this output has been renamed to `subnet_cidrs_by_type_by_az`. Please transition to that output and see it for a proper description."
  value       = module.calculate_subnets.subnets_by_type
}

output "route_table_by_subnet_type" {
  description = "DEPRECATED OUTPUT: this output has been renamed to `route_table_attributes_by_type_by_az`. Please transition to that output and see it for a proper description."
  value = {
    # TODO: omit keys if value is null
    "private"         = { for rt, values in awscc_ec2_route_table.private : split("/", rt)[1] => values if split("/", rt)[0] == "private" }
    "public"          = awscc_ec2_route_table.public
    "transit_gateway" = awscc_ec2_route_table.tgw
  }
}

output "nat_gateways_by_az" {
  description = "DEPRECATED OUTPUT: this output has been renamed to `nat_gateway_attributes_by_az`. Please transition to that output and see it for a proper description."
  value       = try(aws_nat_gateway.main, null)
}

output "private_subnet_attributes_by_az" {
  value = try(
    { for subnet, values in aws_subnet.private : split("/", subnet)[1] => values if split("/", subnet)[0] == "private" }
  , null)
  description = "DEPRECATED OUTPUT: this output has been renamed to `multi_private_subnet_attributes_by_az`. Please transition to that output and see it for a proper description."
}

output "route_table_attributes_by_type_by_az" {
  value = {
    # TODO: omit keys if value is null
    # "private"         = awscc_ec2_route_table.private,
    "private"         = { for rt, values in awscc_ec2_route_table.private : split("/", rt)[1] => values if split("/", rt)[0] == "private" }
    "public"          = awscc_ec2_route_table.public
    "transit_gateway" = awscc_ec2_route_table.tgw
  }
  description = "DEPRECATED OUTPUT: this output has been renamed to `rt_attributes_by_type_by_az`. Please transition to that output and see it for a proper description. This was renamed because the data structure of private subnets changed slightly to account for extra private subnets."
}
