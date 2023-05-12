# Print the SQL query to create the RDS endpoint in the Materialize:
output "mz_rds_endpoint_sql" {
  value = <<EOF
    -- Create the private link endpoint in Materialize
    CREATE CONNECTION privatelink_svc TO AWS PRIVATELINK (
        SERVICE NAME '${aws_vpc_endpoint_service.mz_rds_lb_endpoint_service.service_name}',
        AVAILABILITY ZONES (${join(", ", [for s in data.aws_subnet.mz_rds_subnet : format("%q", s.availability_zone_id)])})
    );

    -- Get the allowed principals for the VPC endpoint service
    SELECT principal
    FROM mz_aws_privatelink_connections plc
    JOIN mz_connections c ON plc.id = c.id
    WHERE c.name = 'privatelink_svc';

    -- IMPORTANT: Get the allowed principals, then add them to the VPC endpoint service

    -- Create the connection to the RDS instance
    CREATE CONNECTION pg_conn TO POSTGRES (
        HOST '${data.aws_db_instance.mz_rds_instance.address}',
        PORT ${data.aws_db_instance.mz_rds_instance.port},
        DATABASE postgres,
        USER postgres,
        PASSWORD SECRET pgpass,
        AWS PRIVATELINK privatelink_svc
    );
    EOF
}

# Return the aws_vpc_endpoint_service resource for the RDS endpoint service including the service name and ID
output "mz_rds_endpoint_service" {
  value = aws_vpc_endpoint_service.mz_rds_lb_endpoint_service
}

# Return the list of subnet IDs for the RDS instance
output "mz_rds_azs" {
  value = [for s in data.aws_subnet.mz_rds_subnet : s.availability_zone_id]
}
