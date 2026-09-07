# terraform-aws-vpc v5 — Gateway VPC endpoints and route-table associations

locals {
  gateway_endpoints_to_create = {
    for key, endpoint in var.gateway_endpoints : key => endpoint if endpoint.create
  }
  gateway_endpoint_ids_by_key = {
    for key, endpoint in var.gateway_endpoints : key => (
      endpoint.create ? aws_vpc_endpoint.gateway[key].id : endpoint.endpoint_id
    )
  }
  # Grouping avoids a duplicate-object-key evaluation error so the dedicated
  # variable validation reports duplicate services cleanly at plan time.
  gateway_endpoint_keys_by_service = {
    for key, endpoint in var.gateway_endpoints : endpoint.service => key...
  }
  gateway_endpoint_ids_by_service = {
    for service, keys in local.gateway_endpoint_keys_by_service :
    service => local.gateway_endpoint_ids_by_key[keys[0]]
  }
  gateway_endpoint_route_table_associations = merge([
    for service, endpoint_keys in local.gateway_endpoint_keys_by_service : {
      for route_key, route_table in local.route_table_targets :
      "${route_key}/gateway-endpoint/${service}" => {
        endpoint_id    = local.gateway_endpoint_ids_by_key[endpoint_keys[0]]
        route_table_id = route_table.route_table_id
        service        = service
      }
      if service == "s3" ? route_table.routing.s3_gateway_endpoint : route_table.routing.dynamodb_gateway_endpoint
    }
  ]...)
  any_gateway_endpoint_routing = anytrue(flatten([
    for name, routing in local.resolved_routing : [
      routing.s3_gateway_endpoint,
      routing.dynamodb_gateway_endpoint,
    ]
  ]))
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoints_to_create

  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current[0].region}.${each.value.service}"
  vpc_endpoint_type = "Gateway"
  policy            = each.value.policy

  tags = merge(var.tags, each.value.tags, {
    Name = replace(replace(replace(
      each.value.name_format,
      "{vpc}", var.vpc.name,
    ), "{service}", each.value.service), "{key}", each.key)
  })
}

resource "terraform_data" "gateway_endpoint_routing_validation" {
  count = local.any_gateway_endpoint_routing ? 1 : 0

  lifecycle {
    precondition {
      condition = alltrue([
        for name, routing in local.resolved_routing :
        !routing.s3_gateway_endpoint || contains(keys(local.gateway_endpoint_ids_by_service), "s3")
      ])
      error_message = "routing.s3_gateway_endpoint=true requires exactly one configured gateway_endpoints entry with service=s3."
    }

    precondition {
      condition = alltrue([
        for name, routing in local.resolved_routing :
        !routing.dynamodb_gateway_endpoint || contains(keys(local.gateway_endpoint_ids_by_service), "dynamodb")
      ])
      error_message = "routing.dynamodb_gateway_endpoint=true requires exactly one configured gateway_endpoints entry with service=dynamodb."
    }
  }
}

resource "aws_vpc_endpoint_route_table_association" "gateway" {
  for_each = local.gateway_endpoint_route_table_associations

  route_table_id  = each.value.route_table_id
  vpc_endpoint_id = each.value.endpoint_id

  depends_on = [terraform_data.gateway_endpoint_routing_validation]
}
