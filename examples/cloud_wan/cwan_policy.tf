
data "aws_networkmanager_core_network_policy_document" "policy" {
  core_network_configuration {
    vpn_ecmp_support = true
    asn_ranges       = ["64515-64520"]

    edge_locations {
      location = var.cloud_wan_regions.nvirginia
      asn      = 64515
    }

    edge_locations {
      location = var.cloud_wan_regions.ireland
      asn      = 64516
    }
  }

  segments {
    name                          = "prod"
    description                   = "Segment for production traffic"
    require_attachment_acceptance = false
  }

  segments {
    name                          = "nonprod"
    description                   = "Segment for non-production traffic"
    require_attachment_acceptance = false
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "or"

    conditions {
      type     = "tag-value"
      operator = "equals"
      key      = "env"
      value    = "prod"
    }

    action {
      association_method = "constant"
      segment            = "prod"
    }
  }

  attachment_policies {
    rule_number     = 200
    condition_logic = "or"

    conditions {
      type     = "tag-value"
      operator = "equals"
      key      = "env"
      value    = "nonprod"
    }

    action {
      association_method = "constant"
      segment            = "nonprod"
    }
  }
}