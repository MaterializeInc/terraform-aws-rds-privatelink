# Generates SQL queries to create the RDS endpoints in Materialize for each RDS instance
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

# Generates SQL queries to create the database connections using the listener port
output "mz_rds_database_connection_sql" {
  description = "SQL queries to create the database connections using the listener port. Run these queries after creating the VPC endpoint service. If you have multiple RDS instances, run these queries for each instance."
  value = { for inst in var.mz_rds_instance_details : inst.name => <<EOF
    -- Create a secret for the password for ${inst.name}
    CREATE SECRET ${inst.name}_dbpass AS 'YOUR_DB_PASSWORD_FOR_${inst.name}';

    -- Create the connection to the RDS instance using the listener port
    CREATE CONNECTION ${inst.name}_db_conn TO ${
      contains(["mysql", "mariadb", "aurora-mysql"], data.aws_db_instance.mz_rds_instance[inst.name].engine) ? "MYSQL" :
      contains(["postgres", "aurora-postgresql"], data.aws_db_instance.mz_rds_instance[inst.name].engine) ? "POSTGRES" :
      upper(data.aws_db_instance.mz_rds_instance[inst.name].engine)
    } (
        HOST '${data.aws_db_instance.mz_rds_instance[inst.name].address}',
        PORT ${inst.listener_port},
        ${contains(["postgres", "aurora-postgresql"], data.aws_db_instance.mz_rds_instance[inst.name].engine) ? 
          "DATABASE ${data.aws_db_instance.mz_rds_instance[inst.name].db_name}," : ""}
        USER ${data.aws_db_instance.mz_rds_instance[inst.name].master_username},
        PASSWORD SECRET ${inst.name}_dbpass,
        AWS PRIVATELINK privatelink_svc
    );
EOF
  }
}

# Return the aws_vpc_endpoint_service resource for the RDS endpoint service including the service name and ID
output "mz_rds_endpoint_service" {
  description = "The aws_vpc_endpoint_service resource for the RDS endpoint service including the service name and ID"
  value = aws_vpc_endpoint_service.mz_rds_lb_endpoint_service
}

# Return the list of subnet IDs for the RDS instances
output "mz_rds_azs" {
  description = "The list of subnet IDs for the RDS instances"
  value = [for s in data.aws_subnet.mz_rds_subnet : s.availability_zone_id]
}

# Return the database instance details for each RDS instance
output "mz_rds_instance" {
  description = "The database instance details for each RDS instance"
  value = { for inst in var.mz_rds_instance_details : inst.name => data.aws_db_instance.mz_rds_instance[inst.name] }
}

# Get the data.dns_a_record_set for each RDS instance
output "mz_rds_dns" {
  description = "The DNS A record set for each RDS instance"
  value = { for inst in var.mz_rds_instance_details : inst.name => data.dns_a_record_set.rds_ip[inst.name] }
}
