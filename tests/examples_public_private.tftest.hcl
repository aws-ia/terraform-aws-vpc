run "plan_validate_public_private_example_root" {
  command = apply

  module {
    source = "./examples/public_private_flow_logs"
  }

  assert {
    condition     = length(module.vpc.public_subnet_attributes_by_az[data.aws_availability_zones.current.names[0]].tags) == 2
    error_message = "Public subnet should have 2 tags total."
  }
  assert {
    condition     = length(module.vpc.private_subnet_attributes_by_az["private/${data.aws_availability_zones.current.names[0]}"].tags) == 1
    error_message = "Private subnets should have 1 tags total."
  }
}

run "apply_validate_s3_flow_logs" {
  command = apply

  module {
    source = "./examples/public_private_flow_logs"
  }
  variables {
    vpc_flow_logs = {
      log_destination_type = "s3"
      kms_key_id           = null
      destination_options = {
        file_format                = "parquet"
        per_hour_partition         = false
        hive_compatible_partitions = false
      }
    }
  }
}

