# Get the state of the RDS instance using aws_db_instance
data "aws_db_instance" "mz_rds_instance" {
  db_instance_identifier = var.mz_rds_instance_name
}

# Get the VPC details using aws_vpc
data "aws_vpc" "mz_rds_vpc" {
  id = var.mz_rds_vpc_id
}

data "aws_db_subnet_group" "mz_rds_subnet_group" {
  name = data.aws_db_instance.mz_rds_instance.db_subnet_group
}

data "aws_subnet" "mz_rds_subnet" {
  for_each = toset(data.aws_db_subnet_group.mz_rds_subnet_group.subnet_ids)
  id       = each.value
}

