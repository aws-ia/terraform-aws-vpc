# Centralized inspection with internet egress

This example creates a three-AZ inspection VPC where spoke traffic arrives through a Transit Gateway attachment, traverses an AZ-local AWS Network Firewall endpoint, and exits through an AZ-local public NAT Gateway. Use it to compose the VPC module with `aws-ia/networkfirewall/aws` while keeping attachment identity, appliance mode, and return routing explicit.

## What this demonstrates

- `subnets.firewall.routing.nat_gateway` sends inspected outbound traffic to the AZ-local NAT Gateway.
- `subnets.firewall.routing.transit_gateway_attachments.inspection` accepts a customer-managed prefix list as a return destination.
- `transit_gateway_attachments.inspection` uses a stable caller key and enables appliance mode while disabling default TGW route-table association and propagation.
- `nat_gateway.mode = "all_azs"` places one public NAT Gateway in each selected AZ.
- Tier 1 subnet and route-table outputs form the input contract for `aws-ia/networkfirewall/aws`.

When a firewall implementation returns AZ-keyed endpoint IDs but does not manage VPC routes, use top-level `routes[*].target.ids_by_az`; the optional Network Firewall composition shown here manages those routes itself.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The Network Firewall module block is intentionally commented there; this excerpt shows the VPC routing and composition boundary:

```hcl
subnets = {
  firewall = {
    role = "private"
    ipv4 = { netmask = 28, cidr_index = 1 }
    routing = {
      nat_gateway = true
      transit_gateway_attachments = {
        inspection = [var.spoke_prefix_list_id]
      }
    }
  }

  tgw_attach = {
    role = "transit_gateway"
    ipv4 = { netmask = 28, cidr_index = 2 }
  }
}

transit_gateway_attachments = {
  inspection = {
    subnet_group                    = "tgw_attach"
    id                              = var.transit_gateway_id
    default_route_table_association = false
    default_route_table_propagation = false
    appliance_mode_support          = true
    dns_support                     = true
    security_group_referencing      = true
  }
}

nat_gateway = {
  mode         = "all_azs"
  subnet_group = "public"
}

locals {
  network_firewall_composition = {
    vpc_id      = module.vpc.vpc_id
    number_azs  = length(var.availability_zones)
    vpc_subnets = module.vpc.subnet_ids_by_group_by_az["firewall"]
    routing_configuration = {
      centralized_inspection_with_egress = {
        connectivity_subnet_route_tables = module.vpc.route_table_ids_by_group_by_az["tgw_attach"]
        public_subnet_route_tables       = module.vpc.route_table_ids_by_group_by_az["public"]
        network_cidr_blocks              = var.spoke_network_cidr_blocks
      }
    }
  }
}
```

## Prerequisites and cost

- Terraform `>= 1.5` and AWS provider `>= 6.29`.
- AWS credentials with permissions to create a VPC, subnets, routes, three NAT Gateways, and a TGW VPC attachment.
- An existing Transit Gateway and a customer-managed prefix list in the selected Region. The prefix list must contain the spoke destinations whose return traffic uses the TGW.
- Keep `spoke_network_cidr_blocks` aligned with the destinations used by the Network Firewall public-route-table return routes.
- The example pins `us-east-1a`, `us-east-1b`, and `us-east-1c`; update the Region and all three AZ names together.
- **Cost:** applying the example creates three public NAT Gateways and one TGW VPC attachment, with hourly, processing, and data-transfer charges. The commented Network Firewall module creates nothing; enabling it adds Network Firewall endpoint-hour and traffic-processing charges and requires a reviewed module version plus an existing firewall policy ARN.

## Run

Create `inspection.tfvars` with real external IDs:

```hcl
transit_gateway_id        = "tgw-0123456789abcdef0"
spoke_prefix_list_id      = "pl-0123456789abcdef0"
spoke_network_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]
```

```shell
terraform init
terraform validate
terraform plan -out=tfplan -var-file=inspection.tfvars
terraform apply tfplan
terraform output route_evidence
terraform output network_firewall_inputs
terraform destroy -var-file=inspection.tfvars
```

A successful apply should show three NAT routes and prefix-list-based TGW return routes in `route_evidence`. Enabling the commented Network Firewall module is a separate, reviewed step; do not treat this VPC-only apply as proof that packet inspection is active.
