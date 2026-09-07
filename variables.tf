# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — Typed Contract
#
# Rules: NO type=any, NO count for collections, all for_each keys = "name/az"
# Every resource at the boundary supports create-or-inject pattern.
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# VPC CORE — create-or-inject via vpc.id
# ─────────────────────────────────────────────────────────────────────────────

variable "vpc" {
  nullable    = false
  description = <<-EOT
    VPC configuration. Set `create = false` and `id` to reference an existing VPC.
    The explicit boolean decides resource cardinality, so `id` may be computed by an
    upstream resource or module without making count/for_each unknown.

    Set `igw_create = false` and `igw_id` to inject an existing Internet Gateway.
    Set `eigw_create = false` and `eigw_id` to inject an existing egress-only
    Internet Gateway. Gateway resources are created only when resolved routing
    requires them. Gateway Name tags accept a complete format with `{vpc}`;
    gateway-specific tags override global tags while the generated Name wins last.
  EOT
  type = object({
    name             = string
    create           = optional(bool, true)
    id               = optional(string)
    igw_create       = optional(bool, true)
    igw_id           = optional(string)
    igw_name_format  = optional(string, "{vpc}-igw")
    igw_tags         = optional(map(string), {})
    eigw_create      = optional(bool, true)
    eigw_id          = optional(string)
    eigw_name_format = optional(string, "{vpc}-eigw")
    eigw_tags        = optional(map(string), {})
    instance_tenancy = optional(string, "default")
    dns = optional(object({
      enable_hostnames = optional(bool, true)
      enable_support   = optional(bool, true)
    }), {})
    tags = optional(map(string), {})
  })

  validation {
    condition     = contains(["default", "dedicated", "host"], var.vpc.instance_tenancy)
    error_message = "vpc.instance_tenancy must be one of: default, dedicated, host."
  }

  validation {
    condition     = length(var.vpc.name) > 0
    error_message = "vpc.name must not be empty."
  }

  validation {
    condition = alltrue([
      for format in [var.vpc.igw_name_format, var.vpc.eigw_name_format] :
      length(trimspace(format)) > 0 && !can(regex("\\{[^}]+\\}", replace(format, "{vpc}", "")))
    ])
    error_message = "Gateway name formats must be non-empty and may use only the {vpc} placeholder."
  }

  validation {
    condition = var.vpc.create ? var.vpc.id == null : (
      var.vpc.id != null && length(trimspace(var.vpc.id)) > 0
    )
    error_message = "vpc.create=true requires id=null; vpc.create=false requires a non-empty id (which may be computed)."
  }

  validation {
    condition = var.vpc.igw_create ? var.vpc.igw_id == null : (
      var.vpc.igw_id == null || length(trimspace(var.vpc.igw_id)) > 0
    )
    error_message = "vpc.igw_create=true requires igw_id=null; injection uses igw_create=false with a non-empty igw_id."
  }

  validation {
    condition = var.vpc.eigw_create ? var.vpc.eigw_id == null : (
      var.vpc.eigw_id == null || length(trimspace(var.vpc.eigw_id)) > 0
    )
    error_message = "vpc.eigw_create=true requires eigw_id=null; injection uses eigw_create=false with a non-empty eigw_id."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DEFAULT VPC RESOURCES — opt-in adoption and hardening
# ─────────────────────────────────────────────────────────────────────────────

variable "default_resources" {
  nullable    = false
  description = <<-EOT
    Opt-in management of the VPC's existing default resources. These resources
    are adopted, never created: enabling a selector takes ownership of the
    default security group, network ACL, or route table already created by AWS.

    All selectors default false so v4 migrations and existing callers retain a
    zero-diff plan. Enabling security-group management removes all default SG
    ingress/egress rules. Enabling network-ACL management removes its default
    allow rules. Enabling route-table management removes non-local routes and
    gateway propagation. Review live workloads before adoption.

    name_format controls generated Name tags with {vpc} and {resource}; resource
    resolves to default-security-group, default-network-acl, or default-route-table.
  EOT
  type = object({
    manage_security_group = optional(bool, false)
    manage_network_acl    = optional(bool, false)
    manage_route_table    = optional(bool, false)
    name_format           = optional(string, "{vpc}-{resource}")
    tags                  = optional(map(string), {})
  })
  default = {}

  validation {
    condition = (
      length(trimspace(var.default_resources.name_format)) > 0 &&
      !can(regex("\\{[^}]+\\}", replace(replace(var.default_resources.name_format, "{vpc}", ""), "{resource}", "")))
    )
    error_message = "default_resources.name_format must be non-empty and may use only {vpc} and {resource}."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ADDRESSING — mandatory primary IPv4 plus caller-keyed secondary associations
# ─────────────────────────────────────────────────────────────────────────────

variable "addressing" {
  nullable    = false
  description = <<-EOT
    VPC addressing with one mandatory primary IPv4 block and zero or more
    caller-keyed secondary associations. Each secondary entry is a closed union:
    configure exactly one of `ipv4` or `ipv6`. The family sub-objects mirror the
    subnet contract, keep family-specific arguments impossible to mix, and make
    each map key durable Terraform resource identity.

    The primary block supports static IPv4, IPv4 IPAM, or an empty object when an
    existing VPC supplies the primary CIDR. Secondary entries support create or
    inject mode. IPv6 is always secondary, may be Amazon-provided or allocated
    from IPAM, and supports VPC prefixes /44 through /60 in increments of /4.
    AWS service quotas, rather than this module, govern association cardinality.
  EOT
  type = object({
    primary = object({
      cidr_block     = optional(string)
      ipam_pool_id   = optional(string)
      netmask_length = optional(number)
    })
    secondary = optional(map(object({
      ipv4 = optional(object({
        create         = optional(bool, true)
        association_id = optional(string)
        cidr_block     = optional(string)
        ipam_pool_id   = optional(string)
        netmask_length = optional(number)
      }))
      ipv6 = optional(object({
        create          = optional(bool, true)
        association_id  = optional(string)
        amazon_assigned = optional(bool, false)
        cidr_block      = optional(string)
        ipam_pool_id    = optional(string)
        netmask_length  = optional(number)
      }))
    })), {})
  })

  validation {
    condition = (
      (var.addressing.primary.cidr_block != null ? 1 : 0) +
      (var.addressing.primary.ipam_pool_id != null ? 1 : 0) <= 1
    )
    error_message = "addressing.primary: provide either cidr_block or ipam_pool_id, not both."
  }

  validation {
    condition = (
      (var.addressing.primary.ipam_pool_id == null) ==
      (var.addressing.primary.netmask_length == null)
    )
    error_message = "addressing.primary: netmask_length is valid if and only if ipam_pool_id is set."
  }

  validation {
    condition = alltrue([
      for key in keys(var.addressing.secondary) :
      can(regex("^[a-z0-9][a-z0-9_-]*$", key)) && !strcontains(key, "/")
    ])
    error_message = "addressing.secondary keys must be stable lowercase identifiers without '/'."
  }

  validation {
    condition = alltrue([
      for key, secondary in var.addressing.secondary :
      (secondary.ipv4 != null ? 1 : 0) + (secondary.ipv6 != null ? 1 : 0) == 1
    ])
    error_message = "Each addressing.secondary entry must configure exactly one family: ipv4 or ipv6."
  }

  validation {
    condition = alltrue([
      for key, secondary in var.addressing.secondary : secondary.ipv4 == null ? true : (
        secondary.ipv4.create ? (
          secondary.ipv4.association_id == null &&
          (secondary.ipv4.cidr_block != null ? 1 : 0) + (secondary.ipv4.ipam_pool_id != null ? 1 : 0) == 1 &&
          (secondary.ipv4.ipam_pool_id == null ? secondary.ipv4.netmask_length == null : secondary.ipv4.netmask_length != null)
          ) : (
          secondary.ipv4.association_id != null && length(trimspace(secondary.ipv4.association_id)) > 0 &&
          secondary.ipv4.cidr_block == null && secondary.ipv4.ipam_pool_id == null && secondary.ipv4.netmask_length == null
        )
      )
    ])
    error_message = "Each secondary IPv4 entry must select create mode with exactly one static/IPAM source (and IPAM netmask), or inject mode with association_id only."
  }

  validation {
    condition = alltrue([
      for key, secondary in var.addressing.secondary : secondary.ipv6 == null ? true : (
        secondary.ipv6.create ? (
          secondary.ipv6.association_id == null && (
            secondary.ipv6.amazon_assigned ? (
              secondary.ipv6.cidr_block == null && secondary.ipv6.ipam_pool_id == null && secondary.ipv6.netmask_length == null
              ) : (
              secondary.ipv6.ipam_pool_id != null &&
              (secondary.ipv6.cidr_block != null ? 1 : 0) + (secondary.ipv6.netmask_length != null ? 1 : 0) == 1
            )
          )
          ) : (
          secondary.ipv6.association_id != null && length(trimspace(secondary.ipv6.association_id)) > 0 &&
          !secondary.ipv6.amazon_assigned && secondary.ipv6.cidr_block == null &&
          secondary.ipv6.ipam_pool_id == null && secondary.ipv6.netmask_length == null
        )
      )
    ])
    error_message = "Each secondary IPv6 entry must select create mode with Amazon assignment or IPv6 IPAM (CIDR/netmask), or inject mode with association_id only."
  }

  validation {
    condition = length(distinct(concat(
      [for key, secondary in var.addressing.secondary : secondary.ipv4.association_id if secondary.ipv4 != null && !secondary.ipv4.create],
      [for key, secondary in var.addressing.secondary : secondary.ipv6.association_id if secondary.ipv6 != null && !secondary.ipv6.create],
      ))) == length(concat(
      [for key, secondary in var.addressing.secondary : secondary.ipv4.association_id if secondary.ipv4 != null && !secondary.ipv4.create],
      [for key, secondary in var.addressing.secondary : secondary.ipv6.association_id if secondary.ipv6 != null && !secondary.ipv6.create],
    ))
    error_message = "Injected addressing.secondary association_id values must be unique. One physical VPC association cannot use multiple caller keys."
  }

  validation {
    condition = alltrue([
      for key, secondary in var.addressing.secondary : secondary.ipv6 == null ? true : (
        secondary.ipv6.netmask_length == null ? true : (
          secondary.ipv6.netmask_length >= 44 && secondary.ipv6.netmask_length <= 60 &&
          secondary.ipv6.netmask_length % 4 == 0
        )
      )
    ])
    error_message = "Secondary IPv6 netmask_length must be /44, /48, /52, /56, or /60."
  }

  validation {
    condition = alltrue([
      for key, secondary in var.addressing.secondary : secondary.ipv6 == null || secondary.ipv6.cidr_block == null ? true : (
        can(cidrhost(secondary.ipv6.cidr_block, 0)) &&
        strcontains(secondary.ipv6.cidr_block, ":") &&
        try(tonumber(split("/", secondary.ipv6.cidr_block)[1]) >= 44, false) &&
        try(tonumber(split("/", secondary.ipv6.cidr_block)[1]) <= 60, false) &&
        try(tonumber(split("/", secondary.ipv6.cidr_block)[1]) % 4 == 0, false)
      )
    ])
    error_message = "Secondary IPv6 cidr_block must be a valid /44, /48, /52, /56, or /60 IPv6 prefix."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# AVAILABILITY ZONES
#
# IMPORTANT: `count` mode takes the first N AZs alphabetically from the
# region. If AWS launches a new AZ that sorts before existing ones, your AZ set
# changes. For PRODUCTION deployments, ALWAYS use explicit `names`. The `count`
# mode is intended for development/prototyping where AZ stability is not critical.
# ─────────────────────────────────────────────────────────────────────────────

variable "availability_zones" {
  nullable    = false
  description = <<-EOT
    AZ selection. Provide either an explicit list of AZ names or a count
    (takes first N from the region alphabetically). Exactly one is required.

    ⚠️  `count` mode is for DEVELOPMENT ONLY. For production, always use explicit
    `names` to guarantee AZ stability. Because `count` resolves AZ names through an
    AWS data source, preconditions that depend on the resolved AZ set are unknown
    during the initial plan and are deferred by Terraform to apply time.
  EOT
  type = object({
    names = optional(list(string))
    count = optional(number)
  })

  validation {
    condition = (
      (var.availability_zones.names != null ? 1 : 0) +
      (var.availability_zones.count != null ? 1 : 0) == 1
    )
    error_message = "Provide exactly one of availability_zones.names or availability_zones.count."
  }

  validation {
    condition = var.availability_zones.count == null ? true : (
      var.availability_zones.count >= 1 && var.availability_zones.count <= 6
    )
    error_message = "availability_zones.count must be between 1 and 6."
  }

  validation {
    condition = var.availability_zones.names == null ? true : (
      length(var.availability_zones.names) >= 1 && length(var.availability_zones.names) <= 6
    )
    error_message = "availability_zones.names must contain between 1 and 6 AZs."
  }

  validation {
    condition = var.availability_zones.names == null ? true : (
      length(distinct(var.availability_zones.names)) == length(var.availability_zones.names)
    )
    error_message = "availability_zones.names must not contain duplicates."
  }
}

variable "calculated_subnet_az_capacity" {
  description = <<-EOT
    Number of AZ slots reserved per calculated subnet group. The default of
    three matches the most common regional layout (three AZs). Deployments in
    regions with more AZs may raise it up to six; the value must always cover
    every configured AZ. Changing it on an existing VPC renumbers calculated
    subnets, so established deployments must keep the value they were created
    with.
  EOT
  type        = number
  default     = 3

  validation {
    condition = (
      var.calculated_subnet_az_capacity >= 1 &&
      var.calculated_subnet_az_capacity <= 6 &&
      floor(var.calculated_subnet_az_capacity) == var.calculated_subnet_az_capacity
    )
    error_message = "calculated_subnet_az_capacity must be an integer between 1 and 6."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# TRANSIT GATEWAY ATTACHMENTS — plural, caller-keyed create-or-inject
# ─────────────────────────────────────────────────────────────────────────────

variable "transit_gateway_attachments" {
  nullable    = false
  description = <<-EOT
    Transit Gateway VPC attachments keyed by caller-owned state identity. AWS
    permits up to five distinct Transit Gateways per VPC, while still allowing
    only one attachment from a given VPC to the same Transit Gateway. Each entry
    selects a transit_gateway subnet group and independently supports create or
    inject. Route maps under subnets[*].routing reference these attachment keys.

    The legacy singular subnets[*].transit_gateway_options shape remains as a
    deprecated adapter, may appear on at most one subnet group, and must not be
    combined with this plural map. Use this top-level map for multiple attachments.
  EOT
  type = map(object({
    subnet_group                    = string
    id                              = string
    create                          = optional(bool, true)
    attachment_id                   = optional(string)
    default_route_table_association = optional(bool, true)
    default_route_table_propagation = optional(bool, true)
    appliance_mode_support          = optional(bool, false)
    dns_support                     = optional(bool, true)
    security_group_referencing      = optional(bool, true)
    tags                            = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = (
      length(var.transit_gateway_attachments) <= 5 &&
      length(distinct([for attachment in values(var.transit_gateway_attachments) : attachment.id])) == length(var.transit_gateway_attachments) &&
      alltrue([
        for key in keys(var.transit_gateway_attachments) :
        can(regex("^[a-z0-9][a-z0-9_-]*$", key)) && !strcontains(key, "/")
      ])
    )
    error_message = "transit_gateway_attachments supports at most five stable lowercase keys without '/', and each entry must select a distinct Transit Gateway ID."
  }

  validation {
    condition = alltrue([
      for key, attachment in var.transit_gateway_attachments :
      length(trimspace(attachment.subnet_group)) > 0 &&
      length(trimspace(attachment.id)) > 0 &&
      (attachment.create ? attachment.attachment_id == null : (
        attachment.attachment_id != null && length(trimspace(attachment.attachment_id)) > 0
      ))
    ])
    error_message = "Each plural TGW attachment requires non-empty subnet_group/id and either create=true with attachment_id=null or create=false with a non-empty attachment_id."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# SUBNETS — typed with explicit roles and co-located routing
#
# STATE KEY CONTRACT:
#   Map keys are IMMUTABLE after initial deployment. The state address of every
#   subnet is `aws_subnet.main["<key>/<az>"]`. Renaming a key destroys and
#   recreates all subnets in that group. To rename safely, use Terraform `moved`
#   blocks in your root module:
#     moved { from = aws_subnet.main["old_name/az"] to = aws_subnet.main["new_name/az"] }
#
#   Keys must be stable identifiers (lowercase, alphanumeric + hyphens).
#   If you need a display name different from the state key, use `name_prefix`.
#
# NETMASK STABILITY:
#   When using `ipv4.netmask`, CIDRs are calculated deterministically:
#   - Every group reserves `calculated_subnet_az_capacity` AZ slots (default 3,
#     raisable to 6), so appending AZs within that capacity does not move CIDRs
#   - Pinned groups use absolute `cidr_index` slots and never move
#   - Unpinned groups pack largest-first, then alphabetically; adding/removing a
#     group affects unpinned groups that sort after it
#   - Overlapping pins across different netmasks fail at plan time
#   - For PRODUCTION, explicit `cidrs_by_az` remains the strongest immutability contract
# ─────────────────────────────────────────────────────────────────────────────

variable "subnets" {
  nullable    = false
  description = <<-EOT
    Map of subnet groups. Each key is a stable logical name (used in state keys
    as "key/az"). Keys are IMMUTABLE post-deploy — renaming requires `moved` blocks.

    The `role` field determines creation behavior:
      - public:          gets IGW route, optional NAT gateway hosting
      - private:         standard private subnet, optional NAT/EIGW routing
      - isolated:        no Internet/transit routing; S3/DynamoDB gateway endpoints allowed
      - transit_gateway: dedicated small subnets for TGW ENIs
      - core_network:    dedicated small subnets for Cloud WAN attachments

    Multiple subnet groups per role are allowed:
      - public: N groups allowed (e.g. DMZ, edge, GWLB)
      - transit_gateway: N groups allowed; each plural attachment selects one group,
        and several attachments may intentionally reuse the same attachment subnets
      - core_network: limited to 1 group (Cloud WAN attachment adapter is singular)

    Set `manage_route_table = false` plus `route_table_key` and `route_table_id`
    to inject an existing route table. `route_table_key` is caller-owned, immutable
    Terraform state identity; renaming it changes every `injected/<key>/...` route
    and gateway-endpoint association address and requires root-module `moved` blocks.
    Changing `manage_route_table` after deployment is an ownership handoff, not an
    in-place toggle: `true` to `false` removes the managed tables and re-keys
    top-level routes from `<route-key>/<az>` to `<route-key>/shared`. Preserve tables
    with root-module `removed` blocks using `destroy = false`, and stage the route
    cutover when an interruption is unacceptable.
    Groups sharing one physical table must use the same key and ID. The module
    associates every subnet while materializing each route and gateway-endpoint
    association only once per physical key. For role = "isolated", an injected
    route table is rejected by default because the AWS provider omits propagated
    and service-managed route classes from its route-table data source; the module
    cannot prove that an unmanaged table is isolated. The dangerous
    isolated_accepts_uninspected_route_table opt-in is the only supported path and
    transfers responsibility for every existing and future route to the caller.
    A shared injected table cannot provide per-AZ NAT targets,
    so `nat_gateway.mode = "all_azs"` is rejected when any referencing group
    requests NAT/NAT64.

    `name_format` controls the complete subnet Name tag with `{vpc}`, `{group}`,
    and `{az}` placeholders. `{group}` resolves `name_prefix` or the map key.
    `route_table_name_format` can diverge; when omitted it inherits `name_format`.

    `public_options.map_public_ip` is opt-in and defaults to false, matching v4:
    a public route table does not imply automatic public IPv4 assignment to ENIs.

    `network_acl` is optional. When absent, the module creates no NACL resources or
    associations and AWS default-NACL behavior is retained. Create mode owns one ACL
    per group; inject mode uses an existing ID while still managing declared rules
    and every subnet association. Ingress/egress maps are keyed by explicit AWS rule
    number so source declaration order never becomes state identity.
  EOT
  type = map(object({
    role         = string
    create       = optional(bool, true)
    existing_ids = optional(map(string))

    # ── IPv4 Addressing (one of netmask/cidrs_by_az/ipam required unless ipv6 native_only) ──
    ipv4 = optional(object({
      netmask        = optional(number)
      cidrs_by_az    = optional(map(string))
      ipam_pool_id   = optional(string)
      netmask_length = optional(number)
      # Absolute CIDR group slot for pinning. Each slot reserves
      # `calculated_subnet_az_capacity` AZ-sized CIDRs (default 3) at this netmask.
      # Pinned ranges never move when groups or AZs
      # are added/removed; overlapping pins across netmasks are rejected.
      cidr_index         = optional(number)
      secondary_cidr_key = optional(string)
    }))

    # ── IPv6 Addressing ──
    ipv6 = optional(object({
      secondary_cidr_key = optional(string)
      auto_assign        = optional(bool, false)
      cidrs_by_az        = optional(map(string))
      ipam_pool_id       = optional(string)
      netmask_length     = optional(number)
      native_only        = optional(bool, false)
      cidr_index         = optional(number)
    }))

    # ── Naming, Tags, and Route Table Injection ──
    name_prefix                              = optional(string)
    name_format                              = optional(string)
    route_table_name_format                  = optional(string)
    tags                                     = optional(map(string), {})
    manage_route_table                       = optional(bool, true)
    route_table_key                          = optional(string) # stable physical identity when injecting
    route_table_id                           = optional(string) # effective ID when injecting
    isolated_accepts_uninspected_route_table = optional(bool, false)

    # ── Optional stateless Network ACL (one per subnet group) ──
    # Rule map keys are the explicit AWS rule numbers and therefore stable state
    # identity, independent of declaration order.
    network_acl = optional(object({
      create      = optional(bool, true)
      id          = optional(string)
      name_format = optional(string, "{vpc}-{group}-nacl")
      tags        = optional(map(string), {})
      ingress = optional(map(object({
        protocol        = string
        action          = string
        cidr_block      = optional(string)
        ipv6_cidr_block = optional(string)
        from_port       = optional(number)
        to_port         = optional(number)
        icmp_type       = optional(number)
        icmp_code       = optional(number)
      })), {})
      egress = optional(map(object({
        protocol        = string
        action          = string
        cidr_block      = optional(string)
        ipv6_cidr_block = optional(string)
        from_port       = optional(number)
        to_port         = optional(number)
        icmp_type       = optional(number)
        icmp_code       = optional(number)
      })), {})
    }))

    # ── Routing (co-located per subnet group) ──
    # transit_gateway and core_network accept lists of destinations
    # to support multiple routes (e.g. 10.0.0.0/8 + 172.16.0.0/12 → TGW).
    # internet_gateway defaults to null; auto-resolved as true for
    # role="public", false otherwise. Set explicitly to override.
    routing = optional(object({
      nat_gateway                      = optional(bool, false)
      egress_only_igw                  = optional(bool, false)
      internet_gateway                 = optional(bool)                  # null = auto (true for public, false otherwise)
      dns64                            = optional(bool, false)           # Also creates 64:ff9b::/96 -> NAT GW; requires NAT
      transit_gateway                  = optional(list(string))          # DEPRECATED singular adapter
      transit_gateway_ipv6             = optional(list(string))          # DEPRECATED singular adapter
      transit_gateway_attachments      = optional(map(list(string)), {}) # attachment key => IPv4 CIDR/prefix-list destinations
      transit_gateway_attachments_ipv6 = optional(map(list(string)), {}) # attachment key => IPv6 CIDR/prefix-list destinations
      core_network                     = optional(list(string))          # list of CIDRs/prefix-list IDs to route via CWAN
      core_network_ipv6                = optional(list(string))          # list of IPv6 CIDRs/prefix-list IDs
      s3_gateway_endpoint              = optional(bool, false)
      dynamodb_gateway_endpoint        = optional(bool, false)
    }), {})

    # Caller-owned route keys are Terraform state identity; destination and
    # target IDs remain values and may therefore be computed during plan.
    routes = optional(map(object({
      destination = object({
        type  = string # ipv4_cidr | ipv6_cidr | prefix_list
        value = string
      })
      target = object({
        type = string # vpc_peering | vpc_endpoint | network_interface | virtual_private_gateway | local_gateway | carrier_gateway
        id   = string
      })
    })), {})

    # ── Public role options ──
    public_options = optional(object({
      map_public_ip = optional(bool, false)
    }))

    # ── Transit Gateway attachment options ──
    transit_gateway_options = optional(object({
      id                              = string
      create                          = optional(bool, true)
      attachment_id                   = optional(string)
      default_route_table_association = optional(bool, true)
      default_route_table_propagation = optional(bool, true)
      appliance_mode_support          = optional(bool, false)
      dns_support                     = optional(bool, true)
      security_group_referencing      = optional(bool, true) # Requires provider >= 5.69
    }))

    # ── Core Network (Cloud WAN) attachment options ──
    core_network_options = optional(object({
      id                 = string
      arn                = optional(string) # Optional: auto-derived from id if omitted
      create             = optional(bool, true)
      attachment_id      = optional(string)
      appliance_mode     = optional(bool, false)
      require_acceptance = optional(bool, false)
      accept_attachment  = optional(bool, false)
      create_accepter    = optional(bool, true)
      accepter_id        = optional(string)
      # null defers to the AWS service defaults so existing attachments see no diff
      dns_support                = optional(bool)
      security_group_referencing = optional(bool)
      routing_policy_label       = optional(string)
    }))
  }))

  default = {}

  # ── Validations ──

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.create ? v.existing_ids == null : (
        v.existing_ids != null && alltrue([for id in values(v.existing_ids) : length(trimspace(id)) > 0])
      )
    ])
    error_message = "Invalid subnet create/inject groups: ${join(", ", [for key, cfg in var.subnets : key if !(cfg.create ? cfg.existing_ids == null : cfg.existing_ids != null && alltrue([for id in values(cfg.existing_ids) : length(trimspace(id)) > 0]))])}. Create mode requires existing_ids=null; inject mode requires non-empty IDs keyed by AZ."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.manage_route_table ? (
        v.route_table_key == null && v.route_table_id == null
        ) : (
        v.route_table_key != null && can(regex("^[a-z0-9][a-z0-9_-]*$", v.route_table_key)) &&
        v.route_table_id != null && length(trimspace(v.route_table_id)) > 0
      )
    ])
    error_message = "manage_route_table=true requires route_table_key/route_table_id=null; inject mode requires a stable lowercase route_table_key and non-empty route_table_id."
  }

  validation {
    condition = alltrue([
      for key, subnet in var.subnets :
      !subnet.isolated_accepts_uninspected_route_table || (subnet.role == "isolated" && !subnet.manage_route_table)
    ])
    error_message = "isolated_accepts_uninspected_route_table may be true only for role='isolated' with manage_route_table=false. It is a dangerous opt-in that accepts caller responsibility for every existing and future route because the module cannot guarantee isolation for an unmanaged table."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      contains(["public", "private", "isolated", "transit_gateway", "core_network"], v.role)
    ])
    error_message = "Invalid subnet roles: ${join(", ", [for key, cfg in var.subnets : "${key}=${cfg.role}" if !contains(["public", "private", "isolated", "transit_gateway", "core_network"], cfg.role)])}. Allowed roles: public, private, isolated, transit_gateway, core_network."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : !strcontains(k, "/")
    ])
    error_message = "Subnet map keys must not contain '/' (reserved for state key composition as 'name/az')."
  }

  validation {
    condition = alltrue(flatten([
      for key, cfg in var.subnets : [
        for format in [cfg.name_format, cfg.route_table_name_format] : format == null || (
          length(trimspace(format)) > 0 && !can(regex("\\{[^}]+\\}", replace(replace(replace(format, "{vpc}", ""), "{group}", ""), "{az}", "")))
        )
      ]
    ]))
    error_message = "Subnet and route-table name formats must be null or non-empty and may use only {vpc}, {group}, and {az}."
  }

  # Multiple public groups and Transit Gateway attachments are allowed. Cloud
  # WAN remains singleton because its VPC attachment boundary is still singular.
  validation {
    condition     = length([for k, v in var.subnets : k if v.role == "core_network"]) <= 1
    error_message = "At most one subnet group may have role 'core_network' (AWS API: 1 Core Network attachment per VPC)."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.ipv4 != null || try(v.ipv6.native_only, false)
    ])
    error_message = "Each subnet must define ipv4 addressing or set ipv6.native_only = true."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.ipv4 == null ? true : (
        (v.ipv4.netmask != null ? 1 : 0) +
        (v.ipv4.cidrs_by_az != null ? 1 : 0) +
        (v.ipv4.ipam_pool_id != null ? 1 : 0) == 1
      )
    ])
    error_message = "Within ipv4, provide exactly one of: netmask, cidrs_by_az, or ipam_pool_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.transit_gateway_options == null || v.role == "transit_gateway"
    ])
    error_message = "transit_gateway_options may be set only on a subnet group with role 'transit_gateway'. Plural attachments use the top-level transit_gateway_attachments map."
  }

  validation {
    condition = length([
      for key, subnet in var.subnets : key
      if subnet.transit_gateway_options != null
    ]) <= 1
    error_message = "The deprecated subnets[*].transit_gateway_options adapter may be configured on at most one subnet group. Use the top-level transit_gateway_attachments map for multiple attachments."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.role != "core_network" || v.core_network_options != null
    ])
    error_message = "Subnets with role 'core_network' must provide core_network_options."
  }

  # Extended isolated validation: prohibit ALL routing including TGW/CWAN.
  # Explicit empty route lists are equivalent to omission.
  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.role == "isolated" ? (
        !try(v.routing.nat_gateway, false) &&
        !try(v.routing.egress_only_igw, false) &&
        !try(v.routing.dns64, false) &&
        try(v.routing.internet_gateway, null) != true &&
        length(coalesce(try(v.routing.transit_gateway, null), [])) == 0 &&
        length(coalesce(try(v.routing.transit_gateway_ipv6, null), [])) == 0 &&
        alltrue([for destinations in values(try(v.routing.transit_gateway_attachments, {})) : length(destinations) == 0]) &&
        alltrue([for destinations in values(try(v.routing.transit_gateway_attachments_ipv6, {})) : length(destinations) == 0]) &&
        length(coalesce(try(v.routing.core_network, null), [])) == 0 &&
        length(coalesce(try(v.routing.core_network_ipv6, null), [])) == 0
      ) : true
    ])
    error_message = "Isolated subnets must not route to Internet, NAT, EIGW, TGW, or Cloud WAN. S3/DynamoDB gateway endpoint routes remain allowed."
  }

  validation {
    condition = alltrue(flatten([
      for key, subnet in var.subnets : [
        for destinations in concat([
          coalesce(try(subnet.routing.transit_gateway, null), []),
          coalesce(try(subnet.routing.transit_gateway_ipv6, null), []),
          coalesce(try(subnet.routing.core_network, null), []),
          coalesce(try(subnet.routing.core_network_ipv6, null), []),
        ], values(try(subnet.routing.transit_gateway_attachments, {})), values(try(subnet.routing.transit_gateway_attachments_ipv6, {}))) : length(destinations) == length(distinct(destinations))
      ]
    ]))
    error_message = "TGW and Cloud WAN destination lists must not contain duplicates within a subnet group."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : [
        for key, route in subnet.routes :
        can(regex("^[a-z0-9][a-z0-9_-]*$", key)) && !strcontains(key, "/") &&
        contains(["ipv4_cidr", "ipv6_cidr", "prefix_list"], route.destination.type) &&
        length(trimspace(route.destination.value)) > 0 &&
        contains(["vpc_peering", "vpc_endpoint", "network_interface", "virtual_private_gateway", "local_gateway", "carrier_gateway"], route.target.type) &&
        length(trimspace(route.target.id)) > 0
      ]
    ]))
    error_message = "subnets[*].routes keys must be stable lowercase identifiers; destination.type must be ipv4_cidr, ipv6_cidr, or prefix_list; target.type must be one of the documented closed target union; destination values and target IDs must be non-empty."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : [
        for key, route in subnet.routes :
        route.destination.type == "ipv4_cidr" ? (can(cidrhost(route.destination.value, 0)) && !strcontains(route.destination.value, ":")) :
        route.destination.type == "ipv6_cidr" ? (can(cidrhost(route.destination.value, 0)) && strcontains(route.destination.value, ":")) :
        startswith(route.destination.value, "pl-")
      ]
    ]))
    error_message = "Generic route destinations must match their declared type: IPv4 CIDR, IPv6 CIDR, or managed prefix-list ID."
  }

  validation {
    condition = alltrue([
      for group, subnet in var.subnets : subnet.role != "isolated" || length(subnet.routes) == 0
    ])
    error_message = "Isolated subnet groups cannot declare generic routes; gateway endpoint associations remain the only allowed non-local routes."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.ipv4 == null ? true : (
        (v.ipv4.ipam_pool_id == null) == (v.ipv4.netmask_length == null)
      )
    ])
    error_message = "Within ipv4, netmask_length is valid if and only if ipam_pool_id is set."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.ipv4 == null || v.ipv4.cidr_index == null || v.ipv4.netmask != null
    ])
    error_message = "ipv4.cidr_index is valid only with calculated ipv4.netmask mode."
  }

  validation {
    condition = alltrue([
      for key, subnet in var.subnets : subnet.core_network_options == null || (
        !subnet.core_network_options.accept_attachment || subnet.core_network_options.require_acceptance
      )
    ])
    error_message = "core_network_options.accept_attachment=true requires require_acceptance=true. Accepter settings are ignored when accept_attachment=false."
  }

  # Netmask range validation
  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.ipv4 == null ? true : (
        v.ipv4.netmask == null ? true : (
          v.ipv4.netmask >= 16 && v.ipv4.netmask <= 28
        )
      )
    ])
    error_message = "Invalid ipv4.netmask values (allowed 16..28): ${join(", ", [for key, cfg in var.subnets : "${key}=${cfg.ipv4.netmask}" if cfg.ipv4 != null && cfg.ipv4.netmask != null && (cfg.ipv4.netmask < 16 || cfg.ipv4.netmask > 28)])}."
  }

  # cidr_index must be a non-negative integer when provided
  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.ipv4 == null ? true : (
        v.ipv4.cidr_index == null ? true : (
          v.ipv4.cidr_index >= 0 && floor(v.ipv4.cidr_index) == v.ipv4.cidr_index
        )
      )
    ])
    error_message = "ipv4.cidr_index must be a non-negative integer when provided."
  }

  validation {
    condition = length(distinct([
      for k, v in var.subnets : "${coalesce(v.ipv4.secondary_cidr_key, "primary")}/${v.ipv4.netmask}/${v.ipv4.cidr_index}"
      if v.ipv4 != null && v.ipv4.netmask != null && v.ipv4.cidr_index != null
      ])) == length([
      for k, v in var.subnets : k
      if v.ipv4 != null && v.ipv4.netmask != null && v.ipv4.cidr_index != null
    ])
    error_message = "Pinned ipv4.cidr_index values must be unique per selected parent and netmask. Configured pins: ${join(", ", [for key, cfg in var.subnets : "${key}=${coalesce(cfg.ipv4.secondary_cidr_key, "primary")}/${cfg.ipv4.netmask}#${cfg.ipv4.cidr_index}" if cfg.ipv4 != null && cfg.ipv4.netmask != null && cfg.ipv4.cidr_index != null])}."
  }

  validation {
    condition = alltrue([
      for key in keys(var.subnets) : can(regex("^[a-z0-9][a-z0-9_-]*$", key))
    ])
    error_message = "Subnet map keys must start with a lowercase letter or digit and contain only lowercase letters, digits, hyphens, and underscores."
  }

  validation {
    condition = alltrue([
      for group, subnet in var.subnets : subnet.network_acl == null ? true : (
        subnet.network_acl.create ? subnet.network_acl.id == null : (
          subnet.network_acl.id != null && length(trimspace(subnet.network_acl.id)) > 0
        )
      )
    ])
    error_message = "network_acl create mode requires id=null; inject mode requires create=false and a non-empty id. Inject mode still manages declared rules and subnet associations."
  }

  validation {
    condition = alltrue([
      for group, subnet in var.subnets : subnet.network_acl == null ? true : (
        length(trimspace(subnet.network_acl.name_format)) > 0 &&
        !can(regex("\\{[^}]+\\}", replace(replace(subnet.network_acl.name_format, "{vpc}", ""), "{group}", "")))
      )
    ])
    error_message = "network_acl.name_format must be non-empty and may use only {vpc} and {group}."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : subnet.network_acl == null ? [true] : concat(
        [for rule_number in keys(subnet.network_acl.ingress) :
          can(tonumber(rule_number)) &&
          try(floor(tonumber(rule_number)) == tonumber(rule_number), false) &&
          try(tonumber(rule_number) >= 1 && tonumber(rule_number) <= 32766, false) &&
          try(tostring(tonumber(rule_number)) == rule_number, false)
        ],
        [for rule_number in keys(subnet.network_acl.egress) :
          can(tonumber(rule_number)) &&
          try(floor(tonumber(rule_number)) == tonumber(rule_number), false) &&
          try(tonumber(rule_number) >= 1 && tonumber(rule_number) <= 32766, false) &&
          try(tostring(tonumber(rule_number)) == rule_number, false)
        ],
      )
    ]))
    error_message = "Network ACL rule keys must be canonical integer rule numbers from 1 through 32766 (for example, '100')."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : subnet.network_acl == null ? [true] : [
        for rule in concat(values(subnet.network_acl.ingress), values(subnet.network_acl.egress)) :
        lower(rule.protocol) == rule.protocol && (
          contains(["-1", "tcp", "udp", "icmp", "icmpv6"], rule.protocol) || (
            can(tonumber(rule.protocol)) &&
            try(floor(tonumber(rule.protocol)) == tonumber(rule.protocol), false) &&
            try(tonumber(rule.protocol) >= 0 && tonumber(rule.protocol) <= 255, false) &&
            try(tostring(tonumber(rule.protocol)) == rule.protocol, false)
          )
        )
      ]
    ]))
    error_message = "Network ACL rule protocol must be lowercase -1, tcp, udp, icmp, icmpv6, or a canonical integer from 0 through 255."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : subnet.network_acl == null ? [true] : [
        for rule in concat(values(subnet.network_acl.ingress), values(subnet.network_acl.egress)) :
        contains(["allow", "deny"], rule.action)
      ]
    ]))
    error_message = "Network ACL rule action must be allow or deny."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : subnet.network_acl == null ? [true] : [
        for rule in concat(values(subnet.network_acl.ingress), values(subnet.network_acl.egress)) : (
          (rule.cidr_block != null ? 1 : 0) + (rule.ipv6_cidr_block != null ? 1 : 0) == 1 &&
          (rule.cidr_block == null ? true : can(cidrhost(rule.cidr_block, 0)) && !strcontains(rule.cidr_block, ":")) &&
          (rule.ipv6_cidr_block == null ? true : can(cidrhost(rule.ipv6_cidr_block, 0)) && strcontains(rule.ipv6_cidr_block, ":"))
        )
      ]
    ]))
    error_message = "Each Network ACL rule must set exactly one valid IPv4 cidr_block or IPv6 ipv6_cidr_block."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : subnet.network_acl == null ? [true] : [
        for rule in concat(values(subnet.network_acl.ingress), values(subnet.network_acl.egress)) :
        contains(["tcp", "udp", "6", "17"], rule.protocol) ? (
          rule.from_port != null && rule.to_port != null &&
          try(floor(rule.from_port) == rule.from_port && floor(rule.to_port) == rule.to_port, false) &&
          try(rule.from_port >= 0 && rule.from_port <= rule.to_port && rule.to_port <= 65535, false)
          ) : (
          rule.from_port == null && rule.to_port == null
        )
      ]
    ]))
    error_message = "TCP/UDP Network ACL rules require an ordered integer from_port/to_port range from 0 through 65535; other protocols must omit ports."
  }

  validation {
    condition = alltrue(flatten([
      for group, subnet in var.subnets : subnet.network_acl == null ? [true] : [
        for rule in concat(values(subnet.network_acl.ingress), values(subnet.network_acl.egress)) :
        contains(["icmp", "icmpv6", "1", "58"], rule.protocol) ? (
          (rule.icmp_type == null && rule.icmp_code == null) || (
            rule.icmp_type != null && rule.icmp_code != null &&
            try(floor(rule.icmp_type) == rule.icmp_type && floor(rule.icmp_code) == rule.icmp_code, false) &&
            try(rule.icmp_type >= -1 && rule.icmp_type <= 255 && rule.icmp_code >= -1 && rule.icmp_code <= 255, false)
          )
          ) : (
          rule.icmp_type == null && rule.icmp_code == null
        )
      ]
    ]))
    error_message = "ICMP/ICMPv6 type and code must both be omitted or be integers from -1 through 255; non-ICMP protocols must omit them."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.subnets : v.ipv4 == null || v.ipv4.cidrs_by_az == null ? [true] : [
        for az, cidr in v.ipv4.cidrs_by_az : can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")
      ]
    ]))
    error_message = "subnets[*].ipv4.cidrs_by_az values must be valid IPv4 CIDR blocks."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.subnets : v.ipv6 == null || v.ipv6.cidrs_by_az == null ? [true] : [
        for az, cidr in v.ipv6.cidrs_by_az : can(cidrhost(cidr, 0)) && strcontains(cidr, ":") && try(tonumber(split("/", cidr)[1]) == 64, false)
      ]
    ]))
    error_message = "subnets[*].ipv6.cidrs_by_az values must be valid IPv6 /64 CIDR blocks."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.ipv6 == null ? true : (
        v.ipv6.ipam_pool_id != null ? (
          v.ipv6.cidrs_by_az == null && v.ipv6.netmask_length == 64 && v.ipv6.cidr_index == null
          ) : v.ipv6.cidrs_by_az != null ? (
          v.ipv6.netmask_length == null && v.ipv6.cidr_index == null
          ) : (
          v.ipv6.auto_assign && v.ipv6.netmask_length == null
        )
      )
    ])
    error_message = "Within ipv6, select exactly one mode: explicit cidrs_by_az, IPAM with netmask_length=64, or auto-calculated auto_assign=true. Fields from other modes must be null."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.ipv6 == null || v.ipv6.cidr_index == null ? true : (
        v.ipv6.cidrs_by_az == null && v.ipv6.ipam_pool_id == null && v.ipv6.auto_assign &&
        v.ipv6.cidr_index >= 0 && floor(v.ipv6.cidr_index) == v.ipv6.cidr_index
      )
    ])
    error_message = "ipv6.cidr_index is valid only for auto-calculated IPv6 and must be a non-negative integer."
  }

  validation {
    condition = length(distinct([
      for k, v in var.subnets : "${v.ipv6.secondary_cidr_key}/${v.ipv6.cidr_index}"
      if v.ipv6 != null && v.ipv6.cidr_index != null
      ])) == length([
      for k, v in var.subnets : k
      if v.ipv6 != null && v.ipv6.cidr_index != null
    ])
    error_message = "IPv6 subnet groups must have unique cidr_index values within each secondary_cidr_key."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.ipv6 == null ? true : (
        v.ipv6.secondary_cidr_key == null ? false : (
          length(trimspace(v.ipv6.secondary_cidr_key)) > 0 &&
          can(regex("^[a-z0-9][a-z0-9_-]*$", v.ipv6.secondary_cidr_key)) &&
          !strcontains(v.ipv6.secondary_cidr_key, "/")
        )
      )
    ])
    error_message = "subnets[*].ipv6.secondary_cidr_key must be a stable lowercase addressing.secondary key without '/'."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : !try(v.ipv6.native_only, false) || (v.ipv6 != null && v.ipv4 == null)
    ])
    error_message = "IPv6-native subnet groups must define IPv6 addressing and must not configure IPv4."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      (v.role == "public") == (v.public_options != null) || v.public_options == null
    ])
    error_message = "public_options may be set only on subnet groups with role = 'public'."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.transit_gateway_options == null ? true : (
        v.transit_gateway_options.create ? v.transit_gateway_options.attachment_id == null : (
          v.transit_gateway_options.attachment_id != null && length(trimspace(v.transit_gateway_options.attachment_id)) > 0
        )
      )
    ])
    error_message = "Transit Gateway attachment create mode requires attachment_id=null; inject mode requires create=false and a non-empty attachment_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.core_network_options == null ? true : (
        v.core_network_options.create ? v.core_network_options.attachment_id == null : (
          v.core_network_options.attachment_id != null && length(trimspace(v.core_network_options.attachment_id)) > 0
        )
      )
    ])
    error_message = "Cloud WAN attachment create mode requires attachment_id=null; inject mode requires create=false and a non-empty attachment_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.core_network_options == null ? true : (
        v.core_network_options.create_accepter ? v.core_network_options.accepter_id == null : (
          !v.core_network_options.accept_attachment || (
            v.core_network_options.accepter_id != null && length(trimspace(v.core_network_options.accepter_id)) > 0
          )
        )
      )
    ])
    error_message = "Cloud WAN accepter creation requires accepter_id=null; injected acceptance uses create_accepter=false with a non-empty accepter_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.role == "transit_gateway" || v.transit_gateway_options == null
    ])
    error_message = "transit_gateway_options may be set only on subnet groups with role = 'transit_gateway'."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.role == "core_network" || v.core_network_options == null
    ])
    error_message = "core_network_options may be set only on subnet groups with role = 'core_network'."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.subnets : [
        for destination in concat(
          coalesce(try(v.routing.transit_gateway, null), []),
          coalesce(try(v.routing.core_network, null), [])
        ) : (can(cidrhost(destination, 0)) && !strcontains(destination, ":")) || can(regex("^pl-[0-9a-f]+$", destination))
      ]
    ]))
    error_message = "IPv4 TGW/Core Network route destinations must be valid CIDRs or managed prefix list IDs (pl-*)."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.subnets : [
        for destination in concat(
          coalesce(try(v.routing.transit_gateway_ipv6, null), []),
          coalesce(try(v.routing.core_network_ipv6, null), [])
        ) : (can(cidrhost(destination, 0)) && strcontains(destination, ":")) || can(regex("^pl-[0-9a-f]+$", destination))
      ]
    ]))
    error_message = "IPv6 TGW/Core Network route destinations must be valid IPv6 CIDRs or managed prefix list IDs (pl-*)."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# TOP-LEVEL ROUTES — late-bound routing for bidirectional module composition
#
# Dependency-direction invariant: var.routes may feed only aws_route resources
# dedicated to this surface and validation-only terraform_data resources. It must
# never feed subnet, route-table, or output expressions; consumers may need those
# outputs to compute these targets in the same plan.
# ─────────────────────────────────────────────────────────────────────────────

variable "routes" {
  nullable    = false
  description = <<-EOT
    Caller-keyed routes applied to every route table in `from_group`. Use this
    late-bound surface when a target is produced by a module that consumes this
    VPC's subnet outputs. Module-managed tables use state keys
    `<route-key>/<az>`. An injected table is one shared physical table and uses
    `<route-key>/shared`; it accepts only `target.id`. Route keys must not contain
    `/`.

    `target.id` replicates one target to every module-managed AZ or creates one
    route on an injected shared table. `target.ids_by_az` selects the target
    matching each configured AZ and therefore requires module-managed per-AZ route
    tables. Exactly one of `id` and `ids_by_az` must be set. A `prefix_list`
    destination on a table with an S3 or DynamoDB gateway endpoint is rejected
    unless `acknowledge_gateway_endpoint_coexistence=true`, because the endpoint's
    service-managed prefix-list ID cannot be compared during planning.

    AWS requires routes toward a VPC endpoint that are more specific than the local
    route to exactly match a subnet CIDR block. The module applies this middlebox
    constraint to `vpc_endpoint` and `network_interface` targets when a destination
    overlaps a plan-known IPv4 CIDR of a module-managed VPC and subnet. CIDRs of an
    injected VPC, injected subnets, and IPAM-derived subnets cannot be checked at
    plan time; AWS enforces the constraint when the route is created. Destination
    and target types use the same closed unions as `subnets[*].routes`.
  EOT
  type = map(object({
    from_group                               = string
    acknowledge_gateway_endpoint_coexistence = optional(bool, false)
    destination = object({
      type  = string
      value = string
    })
    target = object({
      type      = string
      id        = optional(string)
      ids_by_az = optional(map(string))
    })
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, route in var.routes :
      can(regex("^[a-z0-9][a-z0-9_-]*$", key)) && !strcontains(key, "/") &&
      length(trimspace(route.from_group)) > 0 &&
      contains(["ipv4_cidr", "ipv6_cidr", "prefix_list"], route.destination.type) &&
      length(trimspace(route.destination.value)) > 0 &&
      contains(["vpc_peering", "vpc_endpoint", "network_interface", "virtual_private_gateway", "local_gateway", "carrier_gateway"], route.target.type)
    ])
    error_message = "routes keys must be stable lowercase identifiers without '/'; from_group must be non-empty; destination.type and target.type must use the documented closed unions."
  }

  validation {
    condition = alltrue([
      for key, route in var.routes :
      !(route.destination.type == "prefix_list" && route.target.type == "vpc_endpoint") &&
      !(route.destination.type == "ipv6_cidr" && route.target.type == "carrier_gateway")
    ])
    error_message = "routes destination/target combination is not supported by aws_route: prefix_list cannot target vpc_endpoint, and ipv6_cidr cannot target carrier_gateway."
  }

  validation {
    condition = alltrue([
      for key, route in var.routes :
      (route.target.id != null ? 1 : 0) + (route.target.ids_by_az != null ? 1 : 0) == 1 &&
      (route.target.id == null || length(trimspace(route.target.id)) > 0) &&
      (route.target.ids_by_az == null || alltrue([
        for az, id in route.target.ids_by_az : length(trimspace(az)) > 0 && length(trimspace(id)) > 0
      ]))
    ])
    error_message = "routes[*].target must set exactly one of id or ids_by_az (XOR), and every supplied target ID must be non-empty."
  }

  validation {
    condition = alltrue([
      for key, route in var.routes :
      route.destination.type == "ipv4_cidr" ? (can(cidrhost(route.destination.value, 0)) && !strcontains(route.destination.value, ":")) :
      route.destination.type == "ipv6_cidr" ? (can(cidrhost(route.destination.value, 0)) && strcontains(route.destination.value, ":")) :
      startswith(route.destination.value, "pl-")
    ])
    error_message = "Top-level route destinations must match their declared type: IPv4 CIDR, IPv6 CIDR, or managed prefix-list ID."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# NAT GATEWAY — top-level, VPC-wide concern with create-or-inject EIP
#
# nat_gateway.existing_ids allows injecting existing NAT Gateways
# instead of creating new ones (full create-or-inject pattern).
# ─────────────────────────────────────────────────────────────────────────────

variable "nat_gateway" {
  nullable    = false
  description = <<-EOT
    NAT Gateway configuration. `single_az` and `all_azs` create zonal Gateways;
    `regional` creates one public VPC-level Gateway and repeats its ID by configured
    AZ in Tier 1 outputs so existing route-key shapes remain stable. The `az` field
    is required only for `single_az`. Regional mode rejects both `az` and
    `subnet_group`, does not require public subnets, and does not support private NAT.

    Set `create = false` plus `existing_ids` to inject existing NAT Gateways.
    Zonal maps are keyed by selected AZ; regional injection uses exactly the key
    `regional`. The explicit boolean keeps cardinality plan-known when IDs are computed.

    `connectivity_type` controls public (internet-facing) versus private
    (inter-VPC) zonal NAT. Regional NAT is always public.

    `subnet_group` explicitly selects the group that hosts zonal NAT Gateways.
    It must reference a public group for public NAT or a private group for private
    NAT. Null selects the first compatible group alphabetically. Regional mode is
    VPC-level and therefore requires `subnet_group = null`.

    EIP `create` uses ordinary module-owned EIPs for zonal mode and AWS automatic
    IP/AZ management for regional mode. Regional `byoip_pool` and `existing` use
    manual `availability_zone_address` blocks for every configured AZ; BYOIP creates
    one module-owned EIP per AZ, while existing keeps EIP lifecycle caller-owned.

    `name_format` controls the complete NAT Gateway Name tag. The EIP inherits it
    unless `eip.name_format` is set. Both accept `{vpc}`, `{group}`, and `{az}`;
    regional resource naming resolves both `{group}` and `{az}` to `regional`.
    Zonal NAT/EIP tags inherit host-group tags; regional resources use global plus
    NAT/EIP-specific tags because no host subnet group exists.
  EOT
  type = object({
    mode              = optional(string, "none")
    create            = optional(bool, true)
    az                = optional(string)
    connectivity_type = optional(string, "public") # "public" | "private"
    subnet_group      = optional(string)           # explicit NAT host group; null = first compatible group
    existing_ids      = optional(map(string))      # zonal: az → ID; regional: { regional = ID }
    name_format       = optional(string, "{vpc}-nat-{az}")
    tags              = optional(map(string), {})
    eip = optional(object({
      mode             = optional(string, "create")
      public_ipv4_pool = optional(string)
      allocation_ids   = optional(map(string)) # null unless existing EIPs are selected
      name_format      = optional(string)
      tags             = optional(map(string), {})
    }), { mode = "create" })
  })
  default = { mode = "none" }

  validation {
    condition     = contains(["none", "single_az", "all_azs", "regional"], var.nat_gateway.mode)
    error_message = "nat_gateway.mode must be: none, single_az, all_azs, or regional."
  }

  validation {
    condition = var.nat_gateway.mode != "single_az" || (
      var.nat_gateway.az != null && length(var.nat_gateway.az) > 0
    )
    error_message = "nat_gateway.az is required when mode = 'single_az'."
  }

  validation {
    condition     = var.nat_gateway.mode != "regional" || var.nat_gateway.az == null
    error_message = "nat_gateway.az must be null when mode = 'regional'; Regional NAT Gateway is VPC-level."
  }

  validation {
    condition     = var.nat_gateway.mode != "regional" || var.nat_gateway.subnet_group == null
    error_message = "nat_gateway.subnet_group must be null when mode = 'regional'; Regional NAT Gateway does not use a host subnet."
  }

  validation {
    condition     = var.nat_gateway.mode != "regional" || var.nat_gateway.connectivity_type == "public"
    error_message = "nat_gateway.mode = 'regional' requires connectivity_type = 'public'; private NAT remains zonal."
  }

  # allocation_ids is nullable; existing mode requires a non-null map
  validation {
    condition = try(var.nat_gateway.eip.mode, "create") == "create" ? true : (
      var.nat_gateway.eip.mode == "byoip_pool" ? var.nat_gateway.eip.public_ipv4_pool != null :
      var.nat_gateway.eip.mode == "existing" ? (
        var.nat_gateway.eip.allocation_ids != null && length(var.nat_gateway.eip.allocation_ids) > 0
      ) : false
    )
    error_message = "eip.mode='byoip_pool' requires public_ipv4_pool; eip.mode='existing' requires allocation_ids (non-null, non-empty)."
  }

  validation {
    condition     = try(contains(["create", "byoip_pool", "existing"], var.nat_gateway.eip.mode), true)
    error_message = "nat_gateway.eip.mode must be: create, byoip_pool, or existing."
  }

  validation {
    condition = var.nat_gateway.mode == "none" ? var.nat_gateway.existing_ids == null : (
      var.nat_gateway.create ? var.nat_gateway.existing_ids == null : var.nat_gateway.existing_ids != null
    )
    error_message = "NAT create mode requires existing_ids=null; inject mode requires create=false and existing_ids with the selected AZ keys."
  }

  validation {
    condition     = contains(["public", "private"], var.nat_gateway.connectivity_type)
    error_message = "nat_gateway.connectivity_type must be 'public' or 'private'."
  }

  validation {
    condition = alltrue([
      for format in [var.nat_gateway.name_format, var.nat_gateway.eip.name_format] : format == null || (
        length(trimspace(format)) > 0 && !can(regex("\\{[^}]+\\}", replace(replace(replace(format, "{vpc}", ""), "{group}", ""), "{az}", "")))
      )
    ])
    error_message = "NAT and EIP name formats must be null or non-empty and may use only {vpc}, {group}, and {az}."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# GATEWAY VPC ENDPOINTS — S3/DynamoDB, create-or-inject
# ─────────────────────────────────────────────────────────────────────────────

variable "gateway_endpoints" {
  nullable    = false
  description = <<-EOT
    Gateway VPC endpoints keyed by a stable caller-owned identifier. Each entry
    explicitly selects service `s3` or `dynamodb`; at most one endpoint per
    service is allowed. Conventional keys are `s3` and `dynamodb`.

    Create mode owns one aws_vpc_endpoint and accepts an optional JSON policy.
    Inject mode uses create=false plus endpoint_id and never owns endpoint policy.
    Route-table associations are declared co-locally under subnet-group routing.
    name_format accepts {vpc}, {service}, and {key}.
  EOT
  type = map(object({
    service     = string
    create      = optional(bool, true)
    endpoint_id = optional(string)
    policy      = optional(string)
    name_format = optional(string, "{vpc}-{service}-gateway-endpoint")
    tags        = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.gateway_endpoints) : can(regex("^[a-z0-9][a-z0-9_-]*$", key)) && !strcontains(key, "/")
    ])
    error_message = "gateway_endpoints keys must be stable lowercase identifiers without '/'."
  }

  validation {
    condition = alltrue([
      for key, endpoint in var.gateway_endpoints : contains(["s3", "dynamodb"], endpoint.service)
    ])
    error_message = "gateway_endpoints[*].service must be s3 or dynamodb."
  }

  validation {
    condition     = length(distinct([for endpoint in values(var.gateway_endpoints) : endpoint.service])) == length(var.gateway_endpoints)
    error_message = "Configure at most one gateway endpoint per service; duplicate s3/dynamodb services are not allowed."
  }

  validation {
    condition = alltrue([
      for key, endpoint in var.gateway_endpoints : endpoint.create ? (
        endpoint.endpoint_id == null
        ) : (
        endpoint.endpoint_id != null && length(trimspace(endpoint.endpoint_id)) > 0 && endpoint.policy == null
      )
    ])
    error_message = "Gateway endpoint create mode requires endpoint_id=null; inject mode requires create=false, a non-empty endpoint_id, and policy=null."
  }

  validation {
    condition = alltrue([
      for key, endpoint in var.gateway_endpoints : endpoint.policy == null || can(jsondecode(endpoint.policy))
    ])
    error_message = "gateway_endpoints[*].policy must be null or valid JSON."
  }

  validation {
    condition = alltrue([
      for key, endpoint in var.gateway_endpoints :
      length(trimspace(endpoint.name_format)) > 0 && !can(regex("\\{[^}]+\\}", replace(replace(replace(endpoint.name_format, "{vpc}", ""), "{service}", ""), "{key}", "")))
    ])
    error_message = "Gateway endpoint name formats must be non-empty and may use only {vpc}, {service}, and {key}."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC FLOW LOGS — native resources, create-or-inject destinations and roles
# ─────────────────────────────────────────────────────────────────────────────

variable "flow_logs" {
  nullable    = false
  description = <<-EOT
    VPC Flow Logs keyed by a stable logical name. Map keys are Terraform state
    identity and must not be renamed without a moved block.

    destination_type accepts cloudwatch, s3, or kinesis (Kinesis Data Firehose).
    CloudWatch supports create-or-inject for both the log group and the VPC Flow
    Logs IAM role. Set `create_destination=false` and/or `create_iam_role=false`
    when injecting computed ARNs. `name_format` controls the Flow Log `Name` tag
    with `{vpc}`/`{key}` placeholders. `cloudwatch_options.name_format` controls
    the log-group tag and inherits the parent format when null. Set either format
    to the empty string to omit `Name` even when caller tag maps contain it.
    `cloudwatch_options.name` is the fixed physical log-group name; set it to the
    exact imported v4 name during migration. `role_name_prefix` is
    passed through exactly (maximum 38 characters) so a moved v4 IAM role keeps its
    original prefix and is not replaced. S3 buckets and Firehose delivery streams
    are external resources: destination_arn is required so their lifecycle, KMS,
    retention, and ownership policies remain outside this VPC module.

    Migration note: use the exact v4 physical name with three root declarative
    `removed { destroy=false }` blocks (log group, managed policy, attachment)
    plus the log-group `import` handoff. Provider import records the observed name
    and a computed name_prefix; omitting name_prefix in v5 avoids drift.
  EOT
  type = map(object({
    enabled                        = optional(bool, true)
    create                         = optional(bool, true)
    id                             = optional(string)
    destination_type               = optional(string, "cloudwatch")
    create_destination             = optional(bool, true)
    destination_arn                = optional(string)
    create_iam_role                = optional(bool, true)
    iam_role_arn                   = optional(string)
    deliver_cross_account_role_arn = optional(string)
    traffic_type                   = optional(string, "ALL")
    log_format                     = optional(string)
    max_aggregation_interval       = optional(number, 600)
    name_format                    = optional(string, "{vpc}-{key}-flow-logs")
    role_name_prefix               = optional(string)
    role_permissions_boundary      = optional(string)
    cloudwatch_options = optional(object({
      name              = optional(string)
      name_format       = optional(string)
      retention_in_days = optional(number, 30)
      kms_key_id        = optional(string)
    }), {})
    s3_options = optional(object({
      file_format                = optional(string, "plain-text")
      hive_compatible_partitions = optional(bool, false)
      per_hour_partition         = optional(bool, false)
    }), {})
    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : !cfg.enabled ? (cfg.id == null) : (
        cfg.create ? cfg.id == null : (cfg.id != null && length(trimspace(cfg.id)) > 0)
      )
    ])
    error_message = "Enabled Flow Log create mode requires id=null; inject mode requires create=false and a non-empty id. Disabled Flow Logs must not set id."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : contains(["cloudwatch", "s3", "kinesis"], cfg.destination_type)
    ])
    error_message = "flow_logs[*].destination_type must be cloudwatch, s3, or kinesis."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : contains(["ALL", "ACCEPT", "REJECT"], cfg.traffic_type)
    ])
    error_message = "flow_logs[*].traffic_type must be ALL, ACCEPT, or REJECT."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : contains([60, 600], cfg.max_aggregation_interval)
    ])
    error_message = "flow_logs[*].max_aggregation_interval must be 60 or 600 seconds."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : can(regex("^[a-z0-9][a-z0-9-]*$", name)) && !strcontains(name, "/")
    ])
    error_message = "Flow log map keys must use lowercase alphanumeric characters and hyphens, and must not contain '/'."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : contains(["plain-text", "parquet"], cfg.s3_options.file_format)
    ])
    error_message = "flow_logs[*].s3_options.file_format must be plain-text or parquet."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : !cfg.enabled || !cfg.create || cfg.destination_type == "cloudwatch" || cfg.iam_role_arn == null
    ])
    error_message = "flow_logs[*].iam_role_arn is only valid for destination_type = cloudwatch."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : !cfg.enabled || !cfg.create ? true : cfg.destination_type != "cloudwatch" ? (
        cfg.destination_arn != null && length(trimspace(cfg.destination_arn)) > 0
        ) : cfg.create_destination ? cfg.destination_arn == null : (
        cfg.destination_arn != null && length(trimspace(cfg.destination_arn)) > 0
      )
    ])
    error_message = "CloudWatch destination creation requires destination_arn=null; injection requires create_destination=false and a non-empty destination_arn. S3/Firehose always require an ARN."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : !cfg.enabled || !cfg.create ? true : cfg.destination_type != "cloudwatch" ? true : (
        cfg.create_iam_role ? cfg.iam_role_arn == null : (
          cfg.iam_role_arn != null && length(trimspace(cfg.iam_role_arn)) > 0
        )
      )
    ])
    error_message = "CloudWatch role creation requires iam_role_arn=null; injection requires create_iam_role=false and a non-empty iam_role_arn."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : cfg.cloudwatch_options.name == null || length(trimspace(cfg.cloudwatch_options.name)) > 0
    ])
    error_message = "flow_logs[*].cloudwatch_options.name must be null or a non-empty fixed log-group name."
  }

  validation {
    condition = alltrue(flatten([
      for name, cfg in var.flow_logs : [
        for format in compact([cfg.name_format, cfg.cloudwatch_options.name_format]) :
        length(trimspace(format)) > 0 && !can(regex("\\{[^}]+\\}", replace(replace(format, "{vpc}", ""), "{key}", "")))
      ]
    ]))
    error_message = "Flow Log Name formats may be empty to omit Name; otherwise they must be non-blank and may use only {vpc} and {key}."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : cfg.role_name_prefix == null || (
        length(trimspace(cfg.role_name_prefix)) > 0 && length(cfg.role_name_prefix) <= 38
      )
    ])
    error_message = "flow_logs[*].role_name_prefix must be null or a non-empty IAM role name prefix of at most 38 characters."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : contains([
        1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731,
        1096, 1827, 2192, 2557, 2922, 3288, 3653
      ], cfg.cloudwatch_options.retention_in_days)
    ])
    error_message = "flow_logs[*].cloudwatch_options.retention_in_days must be a retention period supported by CloudWatch Logs."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.flow_logs : cfg.deliver_cross_account_role_arn == null || length(trimspace(cfg.deliver_cross_account_role_arn)) > 0
    ])
    error_message = "flow_logs[*].deliver_cross_account_role_arn must be null or a non-empty ARN."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC LATTICE — typed Service Network association
# ─────────────────────────────────────────────────────────────────────────────

variable "vpc_lattice" {
  nullable    = false
  description = "VPC Lattice association. enabled is the plan-known cardinality selector; identifiers may be computed. When private DNS is enabled, dns_options defaults to AWS's VERIFIED_DOMAINS_ONLY behavior."
  type = object({
    enabled                    = optional(bool, false)
    create                     = optional(bool, true)
    id                         = optional(string)
    service_network_identifier = optional(string)
    security_group_ids         = optional(set(string), [])
    private_dns_enabled        = optional(bool, false)
    dns_options = optional(object({
      private_dns_preference        = optional(string, "VERIFIED_DOMAINS_ONLY")
      private_dns_specified_domains = optional(set(string))
    }), {})
    tags = optional(map(string), {})
  })
  default = {}

  validation {
    condition = !var.vpc_lattice.enabled ? var.vpc_lattice.id == null : (
      var.vpc_lattice.create ? (
        var.vpc_lattice.id == null &&
        var.vpc_lattice.service_network_identifier != null &&
        length(trimspace(var.vpc_lattice.service_network_identifier)) > 0 &&
        alltrue([for id in var.vpc_lattice.security_group_ids : length(trimspace(id)) > 0]) &&
        length(var.vpc_lattice.security_group_ids) <= 5
        ) : (
        var.vpc_lattice.id != null && length(trimspace(var.vpc_lattice.id)) > 0 &&
        var.vpc_lattice.service_network_identifier == null && length(var.vpc_lattice.security_group_ids) == 0
      )
    )
    error_message = "VPC Lattice create mode requires a service network and id=null; inject mode requires create=false with id only."
  }

  validation {
    condition = contains([
      "VERIFIED_DOMAINS_ONLY",
      "ALL_DOMAINS",
      "VERIFIED_DOMAINS_AND_SPECIFIED_DOMAINS",
      "SPECIFIED_DOMAINS_ONLY",
    ], var.vpc_lattice.dns_options.private_dns_preference)
    error_message = "vpc_lattice.dns_options.private_dns_preference must be VERIFIED_DOMAINS_ONLY, ALL_DOMAINS, VERIFIED_DOMAINS_AND_SPECIFIED_DOMAINS, or SPECIFIED_DOMAINS_ONLY."
  }

  validation {
    condition = !var.vpc_lattice.enabled || !var.vpc_lattice.create || (
      !var.vpc_lattice.private_dns_enabled ? (
        var.vpc_lattice.dns_options.private_dns_preference == "VERIFIED_DOMAINS_ONLY" &&
        var.vpc_lattice.dns_options.private_dns_specified_domains == null
        ) : (
        contains([
          "VERIFIED_DOMAINS_ONLY",
          "ALL_DOMAINS",
          ], var.vpc_lattice.dns_options.private_dns_preference) ? (
          var.vpc_lattice.dns_options.private_dns_specified_domains == null
          ) : (
          try(length(var.vpc_lattice.dns_options.private_dns_specified_domains), 0) >= 1 &&
          try(length(var.vpc_lattice.dns_options.private_dns_specified_domains), 0) <= 10 &&
          alltrue([
            for domain in coalesce(var.vpc_lattice.dns_options.private_dns_specified_domains, toset([])) :
            length(trimspace(domain)) >= 1 && length(domain) <= 255
          ])
        )
      )
    )
    error_message = "VPC Lattice DNS options require private_dns_enabled=true; specified domains (1-10 non-empty names, up to 255 characters) are allowed only with VERIFIED_DOMAINS_AND_SPECIFIED_DOMAINS or SPECIFIED_DOMAINS_ONLY."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC BLOCK PUBLIC ACCESS — regional options and typed exclusions
# ─────────────────────────────────────────────────────────────────────────────

variable "vpc_block_public_access" {
  nullable    = false
  description = <<-EOT
    Regional VPC Block Public Access options. This is an account/Region singleton;
    enable it from exactly one module instance. create=false injects existing
    options by ID. Exclusions are keyed by stable names and independently support
    create-or-inject. A created exclusion targets this VPC or one subnet.
  EOT
  type = object({
    enabled                     = optional(bool, false)
    create                      = optional(bool, true)
    id                          = optional(string)
    internet_gateway_block_mode = optional(string, "block-ingress")
    exclusions = optional(map(object({
      create                          = optional(bool, true)
      id                              = optional(string)
      internet_gateway_exclusion_mode = optional(string, "allow-bidirectional")
      target                          = optional(string, "vpc")
      subnet_key                      = optional(string)
      subnet_id                       = optional(string)
      tags                            = optional(map(string), {})
    })), {})
  })
  default = {}

  validation {
    condition = !var.vpc_block_public_access.enabled ? (
      var.vpc_block_public_access.id == null && length(var.vpc_block_public_access.exclusions) == 0
      ) : (
      contains(["block-ingress", "block-bidirectional"], var.vpc_block_public_access.internet_gateway_block_mode) &&
      (var.vpc_block_public_access.create ? var.vpc_block_public_access.id == null : (
        var.vpc_block_public_access.id != null && length(trimspace(var.vpc_block_public_access.id)) > 0
      ))
    )
    error_message = "BPA must be disabled without IDs/exclusions, or enabled in block-ingress/block-bidirectional create-or-inject mode."
  }

  validation {
    condition = alltrue([
      for name, exclusion in var.vpc_block_public_access.exclusions :
      contains(["allow-bidirectional", "allow-egress"], exclusion.internet_gateway_exclusion_mode) &&
      (exclusion.internet_gateway_exclusion_mode != "allow-egress" || var.vpc_block_public_access.internet_gateway_block_mode == "block-bidirectional") &&
      (exclusion.create ? exclusion.id == null : (
        exclusion.id != null && length(trimspace(exclusion.id)) > 0
      )) &&
      (exclusion.target == "vpc" ? (
        exclusion.subnet_key == null && exclusion.subnet_id == null
        ) : exclusion.target == "subnet" ? (
        (exclusion.subnet_key != null ? 1 : 0) + (exclusion.subnet_id != null ? 1 : 0) == 1
      ) : false)
    ])
    error_message = "Each BPA exclusion must select a compatible mode, create-or-inject ownership, and exactly one VPC/subnet target. allow-egress requires block-bidirectional."
  }

  validation {
    condition = alltrue([
      for name in keys(var.vpc_block_public_access.exclusions) : can(regex("^[a-z0-9][a-z0-9_-]*$", name)) && !strcontains(name, "/")
    ])
    error_message = "BPA exclusion keys must be stable lowercase identifiers without '/'."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DHCP OPTIONS — typed create-or-inject association
# ─────────────────────────────────────────────────────────────────────────────

variable "dhcp_options" {
  nullable    = false
  description = "DHCP option set for the VPC. Enable create mode from typed settings or inject an existing dhcp_options_id."
  type = object({
    enabled                           = optional(bool, false)
    create                            = optional(bool, true)
    id                                = optional(string)
    domain_name                       = optional(string)
    domain_name_servers               = optional(list(string), ["AmazonProvidedDNS"])
    ntp_servers                       = optional(list(string), [])
    netbios_name_servers              = optional(list(string), [])
    netbios_node_type                 = optional(number)
    ipv6_address_preferred_lease_time = optional(string)
    tags                              = optional(map(string), {})
  })
  default = {}

  validation {
    condition = !var.dhcp_options.enabled ? var.dhcp_options.id == null : (
      var.dhcp_options.create ? var.dhcp_options.id == null : (
        var.dhcp_options.id != null && length(trimspace(var.dhcp_options.id)) > 0
      )
    )
    error_message = "DHCP options create mode requires id=null; inject mode requires create=false and a non-empty id."
  }

  validation {
    condition     = var.dhcp_options.netbios_node_type == null || contains([1, 2, 4, 8], var.dhcp_options.netbios_node_type)
    error_message = "dhcp_options.netbios_node_type must be one of 1, 2, 4, or 8."
  }

  validation {
    condition = alltrue([
      for server in concat(
        var.dhcp_options.domain_name_servers,
        var.dhcp_options.ntp_servers,
        var.dhcp_options.netbios_name_servers,
      ) : length(trimspace(server)) > 0
    ])
    error_message = "DHCP server lists must not contain empty strings."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL TAGS
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  nullable    = false
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
