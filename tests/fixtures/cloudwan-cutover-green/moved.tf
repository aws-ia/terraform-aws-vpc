# Both attachments remain configured. Only the route's logical owner changes;
# AWS can update its Core Network target without deleting the physical route.
moved {
  from = module.vpc.aws_route.cwan_attachment["workload/us-east-1a/cwan/blue/10.0.0.0-8"]
  to   = module.vpc.aws_route.cwan_attachment["workload/us-east-1a/cwan/green/10.0.0.0-8"]
}

moved {
  from = module.vpc.aws_route.cwan_attachment["workload/us-east-1a/cwan/blue/pl-0123456789abcdef0"]
  to   = module.vpc.aws_route.cwan_attachment["workload/us-east-1a/cwan/green/pl-0123456789abcdef0"]
}

moved {
  from = module.vpc.aws_route.cwan_attachment_ipv6["workload/us-east-1a/cwan6/blue/2001:db8:100::-48"]
  to   = module.vpc.aws_route.cwan_attachment_ipv6["workload/us-east-1a/cwan6/green/2001:db8:100::-48"]
}

moved {
  from = module.vpc.aws_route.cwan_attachment_ipv6["workload/us-east-1a/cwan6/blue/pl-1123456789abcdef0"]
  to   = module.vpc.aws_route.cwan_attachment_ipv6["workload/us-east-1a/cwan6/green/pl-1123456789abcdef0"]
}
