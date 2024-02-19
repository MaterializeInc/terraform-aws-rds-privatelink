provider "aws" {
  region = var.aws_region
}

module "rds-postgres" {
  source  = "MaterializeInc/rds-postgres/aws"
  version = "0.1.3"

  # Module-specific variables...
  rds_instance_name = var.mz_rds_instance_name
  mz_egress_ips     = var.mz_egress_ips
}

# Assuming your module is at the root of your repository
module "materialize_privatelink_rds" {
  source = "../.."

  # Variables for your module...
  mz_rds_instance_name = module.rds_postgres.rds_instance.name
  mz_rds_vpc_id        = module.rds_postgres.rds_instance.vpc_id
}
