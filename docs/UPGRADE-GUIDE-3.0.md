# Changes from 2.x to 3.x

- IPAM vpcs no longer rely on the `aws_vpc_ipam_preview_next_cidr` resource. This is a breaking change for VPCs were built with this resource dependency, with a workaround available. Removing this dependency was the last major [known] sore thumb of this module. With this removed we can now build vpcs in the same module as IPAMs, or, more importantly, prefix lists / transit gateways in the same `apply` as the vpc.
- transit gateway id is now passed as a root level variable. Previously it was passed in var.subnets.transit_gateway.transit_gateway_id. While this was logically a nice way to organize variable references it lead to race conditions if you were trying to create a transit gateway in the same root module as the VPC call.
- route to transit gateway is now passed at a root level via variable `transit_gateway_routes`. Previously it was passed in var.subnets.<subnet-name>.route_to_transit_gateway. While this was logically a nice way to organize variable references it lead to race conditions if you were trying to create the prefix list in the same root module as the VPC call.

# Required Changes to Make

## Regarding changes to Transit Gateway users

Before:

```hcl
module "vpc" {
  ...
  subnets = {
    transit_gateway = {
      transit_gateway_id = <>
      ...
    }
  }
}
```

After:

```hcl
module "vpc" {
  ...
  transit_gateway_id = <>
  subnets = {...}
}
```

## Regarding changes to Transit Gateway Routes using prefix list

Before:

```hcl
module "vpc" {
  ...
  subnets = {
    public = {
      route_to_transit_gateway = <prefix-list-id>
    }
    private = {
      route_to_transit_gateway = <prefix-list-id>
    }
  }
}
```

After:

```hcl
module "vpc" {
  ...
  transit_gateway_id = <>
  transit_gateway_routes = {
    public = <prefix-list-id>
    private   = <prefix-list-id>
  }
  subnets = {...}
}
```

## Regarding changes to IPAM users

Using you were using the [IPAM Example](https://github.com/aws-ia/terraform-aws-vpc/blob/main/examples/ipam/main.tf) and you upgrde to v3, you must make the following changes to avoid a re-build.

1. Upgrade the module `terraform init -upgrade`
1. Remove the preview resource from the state file: `terraform state rm 'module.vpc.aws_vpc_ipam_preview_next_cidr.main[0]'`
1. Make necessary HCL changes

## HCL changes

Before:

```hcl
module "vpc" {
  name     = "ipam-vpc"
  az_count = 3

  vpc_ipv4_ipam_pool_id   = "ipam-pool-079f76df39be519c9"
  vpc_ipv4_netmask_length = 26

  subnets = {
    private = {
      netmask                 = 28
      connect_to_public_natgw = false
    }
  }
}
```

After :

Commenting out lines that can be removed for clarity. Feel free to remove from your module reference

```hcl
module "vpc" {
  name     = "ipam-vpc"
  az_count = 3

  vpc_ipv4_ipam_pool_id   = "ipam-pool-079f76df39be519c9"
  # vpc_ipv4_netmask_length = 26
  cidr_block = "172.2.0.192/26"

  subnets = {
    private = {
      cidrs = ["172.2.0.192/28", "172.2.0.208/28", "172.2.0.224/28"]
      # netmask                 = 28
      connect_to_public_natgw = false
    }
  }
}
```

# Previous upgrade guides

- [v2 Upgrade](https://github.com/aws-ia/terraform-aws-vpc/blob/c60216fed89e9617f9357d894462b1282c63682f/UPGRADE-GUIDE-2.0.md)
