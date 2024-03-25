provider "aws" {
  region = var.aws_region
}

module "rds_postgres" {
  source  = "MaterializeInc/rds-postgres/aws"
  version = "0.1.5"

  rds_instance_name   = var.mz_rds_instance_name
  mz_egress_ips       = var.mz_egress_ips
  aws_region          = var.aws_region
  publicly_accessible = false
}
