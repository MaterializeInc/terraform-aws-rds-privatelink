# Generate SQL queries to create the RDS endpoints in Materialize for each RDS instance
# Generate SQL query to create the PrivateLink endpoint in Materialize just once
output "mz_rds_private_link_endpoint_sql" {
  description = "SQL query to create the PrivateLink endpoint in Materialize. Run this query once after creating the VPC endpoint service."
  value = <<EOF
    -- Create the PrivateLink endpoint in Materialize
    CREATE CONNECTION privatelink_svc TO AWS PRIVATELINK (
        SERVICE NAME '${aws_vpc_endpoint_service.mz_rds_lb_endpoint_service.service_name}',
        AVAILABILITY ZONES (${join(", ", [for s in data.aws_subnet.mz_rds_subnet : format("%q", s.availability_zone_id)])})
    );

    -- Get the allowed principals for the VPC endpoint service
    SELECT principal
    FROM mz_aws_privatelink_connections plc
    JOIN mz_connections c ON plc.id = c.id
    WHERE c.name = 'privatelink_svc';
EOF
}

# Generate SQL queries to create the PostgreSQL connections using the listener port
output "mz_rds_postgres_connection_sql" {
  description = "SQL queries to create the PostgreSQL connections using the listener port. Run these queries after creating the VPC endpoint service. If you have multiple RDS instances, run these queries for each instance."
  value = { for inst in var.mz_rds_instance_details : inst.name => <<EOF
    -- Create a secret for the password for ${inst.name}
    CREATE SECRET ${inst.name}_pgpass AS 'YOUR_PG_PASSWORD_FOR_${inst.name}';

    -- Create the connection to the RDS instance using the listener port
    CREATE CONNECTION ${inst.name}_pg_conn TO POSTGRES (
        HOST '${data.aws_db_instance.mz_rds_instance[inst.name].address}',
        PORT ${inst.listener_port},
        DATABASE postgres,
        USER postgres,
        PASSWORD SECRET ${inst.name}_pgpass,
        AWS PRIVATELINK privatelink_svc
    );
EOF
  }
}

# Return the aws_vpc_endpoint_service resource for the RDS endpoint service including the service name and ID
output "mz_rds_endpoint_service" {
  value = aws_vpc_endpoint_service.mz_rds_lb_endpoint_service
}

# Return the list of subnet IDs for the RDS instances
output "mz_rds_azs" {
  value = [for s in data.aws_subnet.mz_rds_subnet : s.availability_zone_id]
}

# Return the database instance details for each RDS instance
# Return the database instance details for each RDS instance
output "mz_rds_instance" {
  value = { for inst in var.mz_rds_instance_details : inst.name => data.aws_db_instance.mz_rds_instance[inst.name] }
}

# Get the data.dns_a_record_set for each RDS instance
output "mz_rds_dns" {
  value = { for inst in var.mz_rds_instance_details : inst.name => data.dns_a_record_set.rds_ip[inst.name] }
}
