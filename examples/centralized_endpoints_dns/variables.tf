variable "aws_region" {
  description = "AWS Region in which to create the centralized endpoints and DNS topology."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "At least two distinct Availability Zones used by every hub and spoke subnet group."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition = (
      length(var.availability_zones) >= 2 &&
      length(var.availability_zones) <= 6 &&
      length(distinct(var.availability_zones)) == length(var.availability_zones)
    )
    error_message = "availability_zones must contain between two and six distinct AZ names."
  }
}

variable "consumer_cidrs" {
  description = "Additional on-premises or remote consumer CIDRs routed back through the TGW and allowed to use HTTPS endpoints."
  type        = set(string)
  default     = ["192.0.2.0/24"]

  validation {
    condition = (
      length(var.consumer_cidrs) > 0 &&
      alltrue([for cidr in var.consumer_cidrs : can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")])
    )
    error_message = "consumer_cidrs must contain at least one valid IPv4 CIDR."
  }
}

variable "interface_endpoints" {
  description = "Interface endpoint services and the explicit service actions allowed by each endpoint policy."
  type = map(object({
    service = string
    actions = set(string)
  }))

  default = {
    ssm = {
      service = "ssm"
      actions = [
        "ssm:Describe*",
        "ssm:Get*",
        "ssm:List*",
      ]
    }
    ssmmessages = {
      service = "ssmmessages"
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
    }
    ec2messages = {
      service = "ec2messages"
      actions = [
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply",
      ]
    }
    logs = {
      service = "logs"
      actions = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
    }
    sts = {
      service = "sts"
      actions = [
        "sts:GetCallerIdentity",
      ]
    }
  }

  validation {
    condition = (
      length(var.interface_endpoints) > 0 &&
      alltrue([
        for endpoint in values(var.interface_endpoints) :
        endpoint.service != "" && length(endpoint.actions) > 0
      ])
    )
    error_message = "interface_endpoints must declare a non-empty service name and at least one policy action per endpoint."
  }
}

variable "on_prem_dns_cidrs" {
  description = "IPv4 CIDRs of on-premises DNS resolvers allowed to query the inbound Resolver endpoint."
  type        = set(string)
  default     = ["192.0.2.0/24"]

  validation {
    condition = (
      length(var.on_prem_dns_cidrs) > 0 &&
      alltrue([for cidr in var.on_prem_dns_cidrs : can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")])
    )
    error_message = "on_prem_dns_cidrs must contain at least one valid IPv4 CIDR."
  }
}

variable "resolver_inbound_ips_by_az" {
  description = "Optional fixed IPv4 address for the inbound Resolver endpoint in selected AZs."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for ip in values(var.resolver_inbound_ips_by_az) :
      can(cidrhost("${ip}/32", 0)) && !strcontains(ip, ":")
    ])
    error_message = "resolver_inbound_ips_by_az values must be valid IPv4 addresses."
  }
}

variable "resolver_outbound_ips_by_az" {
  description = "Optional fixed IPv4 address for the outbound Resolver endpoint in selected AZs."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for ip in values(var.resolver_outbound_ips_by_az) :
      can(cidrhost("${ip}/32", 0)) && !strcontains(ip, ":")
    ])
    error_message = "resolver_outbound_ips_by_az values must be valid IPv4 addresses."
  }
}

variable "forwarding_rules" {
  description = "Outbound FORWARD rules keyed by stable identity, with named target IPv4 addresses and ports."
  type = map(object({
    domain_name = string
    target_ips = map(object({
      ip   = string
      port = number
    }))
  }))

  default = {
    on-premises = {
      domain_name = "onprem.example.com."
      target_ips = {
        primary   = { ip = "192.0.2.53", port = 53 }
        secondary = { ip = "192.0.2.54", port = 53 }
      }
    }
  }

  validation {
    condition = (
      length(var.forwarding_rules) > 0 &&
      alltrue([
        for rule in values(var.forwarding_rules) :
        rule.domain_name != "" && length(rule.target_ips) > 0 && alltrue([
          for target in values(rule.target_ips) :
          can(cidrhost("${target.ip}/32", 0)) && !strcontains(target.ip, ":") && target.port >= 1 && target.port <= 65535
        ])
      ])
    )
    error_message = "forwarding_rules must declare a domain and at least one valid IPv4 target and TCP/UDP port."
  }
}

variable "private_zones" {
  description = "Private hosted zones and records associated directly with the hub and every spoke VPC."
  type = map(object({
    name = string
    records = map(object({
      name   = string
      type   = string
      ttl    = number
      values = set(string)
    }))
  }))

  default = {
    shared = {
      name = "aws.example.internal"
      records = {
        management = {
          name   = "management.aws.example.internal"
          type   = "A"
          ttl    = 300
          values = ["10.250.0.10"]
        }
      }
    }
  }

  validation {
    condition = alltrue([
      for zone in values(var.private_zones) :
      zone.name != "" && alltrue([
        for record in values(zone.records) :
        record.name != "" && contains(["A", "AAAA", "CNAME", "TXT"], record.type) && record.ttl > 0 && length(record.values) > 0
      ])
    ])
    error_message = "private_zones must use non-empty names and A, AAAA, CNAME, or TXT records with positive TTLs and values."
  }
}

variable "ram_principals" {
  description = "Optional account, organization, or organizational-unit principals receiving the Resolver rule RAM share."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for principal in var.ram_principals :
      can(regex("^(?:[0-9]{12}|arn:(?:aws|aws-us-gov|aws-cn):organizations::[0-9]{12}:(?:organization|ou)/.+)$", principal))
    ])
    error_message = "ram_principals entries must be 12-digit account IDs or AWS Organizations organization/OU ARNs."
  }
}

variable "allow_external_principals" {
  description = "Whether the Resolver rule RAM share accepts principals outside the owning AWS Organization."
  type        = bool
  default     = false
}
