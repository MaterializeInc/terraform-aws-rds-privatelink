# Get the state of the RDS instances using aws_db_instance
data "aws_db_instance" "mz_rds_instance" {
  for_each = { for inst in var.mz_rds_instance_details : inst.name => inst }

  db_instance_identifier = each.key

  lifecycle {
    postcondition {
      condition     = self.publicly_accessible == false && self.replicate_source_db == ""
      error_message = "The RDS instance must be private and a writer instance."
    }
  }
}

# Get the VPC details using aws_vpc
data "aws_vpc" "mz_rds_vpc" {
  id = var.mz_rds_vpc_id
}

data "aws_db_subnet_group" "mz_rds_subnet_group" {
  for_each = { for inst in var.mz_rds_instance_details : inst.name => inst }
  name     = data.aws_db_instance.mz_rds_instance[each.key].db_subnet_group
}

data "aws_subnet" "mz_rds_subnet" {
  for_each = toset(flatten([for inst in var.mz_rds_instance_details : data.aws_db_subnet_group.mz_rds_subnet_group[inst.name].subnet_ids]))

  id = each.value
}

data "dns_a_record_set" "rds_ip" {
  for_each = { for inst in var.mz_rds_instance_details : inst.name => inst }
  host     = data.aws_db_instance.mz_rds_instance[each.key].address
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}
