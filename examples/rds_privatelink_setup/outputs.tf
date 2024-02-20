output "rds_instance_endpoint" {
  value = module.rds_postgres.rds_instance.endpoint
  sensitive = true
}

output "mz_rds_details" {
  value = module.rds_postgres.mz_rds_details
  sensitive = true
}
