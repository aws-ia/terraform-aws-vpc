resource "aws_ec2_transit_gateway" "example" {
  description = "example"
}

resource "aws_ec2_managed_prefix_list" "example" {
  name           = "All VPC CIDR-s"
  address_family = "IPv4"
  max_entries    = 5

  dynamic "entry" {
    for_each = var.prefixes

    content {
      cidr        = entry.value
      description = entry.key
    }
  }
}

