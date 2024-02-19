output "rds_instance_endpoint" {
  value = module.rds_postgres.rds_instance.endpoint
}

output "mz_rds_details" {
  value = module.rds_postgres.mz_rds_details
}
