# Materialize + PrivateLink + RDS

> [!WARNING]
> This is provided on a best-effort basis and Materialize cannot offer support for this module

This repository contains a Terraform module that configures a PrivateLink endpoint for existing Amazon RDS PostgreSQL or MySQL databases to connect to Materialize.

The module creates the following resources:
- Target group for each RDS instance
- Network Load Balancer for the RDS instances
- TCP listener for the NLB to forward traffic to the target groups
- A VPC endpoint service for your RDS instances
- Lambda Function to check and update the IP addresses of the RDS instances in the NLB target groups
- IAM Role and Policy to give the Lambda function necessary permissions
- Event Source Mapping, Event Rule, and Target: Triggers the Lambda function every _n_ minutes
- Lambda Permission: Allows the event to invoke the Lambda function

## Important Remarks

> [!NOTE]
> The RDS instances need to be private. If your RDS instances are public, there is no need to use PrivateLink.

> [!NOTE]
> When using Aurora, the RDS instance needs to be a **writer** instance as the reader instances will not work.

- The RDS instances must be in the same VPC as the PrivateLink endpoint.
- Review this module with your Cloud Security team to ensure that it meets your security requirements.
- Finally, after the Terraform module has been applied, you will need to make sure that the Target Groups health checks are passing. As the NLB does not have security groups, you will need to make sure that the NLB is able to reach the RDS instances by allowing the subnet CIDR blocks in the security groups of the RDS instances.

To override the default AWS provider variables, you can export the following environment variables:

```bash
export AWS_PROFILE=<your_aws_profile> # eg. default
export AWS_CONFIG_FILE=<your_aws_config_file> # eg. ["~/.aws/config"]
export AWS_REGION=<your_aws_region> # eg. us-east-1
```

## Usage

### Variables

Start by copying the `terraform.tfvars.example` file to `terraform.tfvars` and filling in the variables:

```
cp terraform.tfvars.example terraform.tfvars
```

| Name                        | Description | Type | Example | Required |
|-----------------------------|-------------|:----:|:-----:|:-----:|
| `mz_rds_instance_names`     | The name and listener port of the RDS instances | list | `{ name = "instance1", listener_port = 5001 }` | yes |
| `mz_rds_vpc_id`             | The VPC ID of the RDS instance | string | `'vpc-1234567890abcdef0'` | yes |
| `mz_acceptance_required`    | Whether or not to require manual acceptance of new connections | bool | `true` | no |
| `schedule_expression`       | [The scheduling expression](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule#schedule_expression). For example, `cron(0 20 * * ? *)` | string | `'rate(5 minutes)'` | no |
| `cross_zone_load_balancing` | Enables cross zone load balancing for the NLB | bool | `false` | no |

### Apply the Terraform Module

```
terraform apply
```

### Output

After the Terraform module has been applied, you will see the following output.

You can follow the instructions in the output to configure the PrivateLink endpoint and the database connections in Materialize.

First, you will need to create the PrivateLink endpoint in Materialize:

```sql
mz_rds_private_link_endpoint_sql = <<EOT
    -- Create the private link endpoint in Materialize
    CREATE CONNECTION privatelink_svc TO AWS PRIVATELINK (
        SERVICE NAME 'com.amazonaws.vpce.us-east-1.vpce-svc-1234567890abcdef0',
        AVAILABILITY ZONES ("use1-az1", "use1-az2")
    );

    -- Get the allowed principals for the VPC endpoint service
    SELECT principal
        FROM mz_aws_privatelink_connections plc
        JOIN mz_connections c ON plc.id = c.id
        WHERE c.name = 'privatelink_svc';

EOT
```

After that, you will need to create the database connections in Materialize. If you have multiple RDS instances, you will see multiple SQL statements:

```sql
mz_rds_database_connection_sql   = {
    rds-instance-name = <<-EOT
          -- Create a secret for the password for rds-instance-name
              CREATE SECRET rds-instance-name_dbpass AS 'YOUR_DB_PASSWORD_FOR_rds-instance-name';
              -- Create the connection to the RDS instance using the listener port
              CREATE CONNECTION rds-instance-name_db_conn TO POSTGRES (
                  HOST 'rds-instance-name.ctthmav6dsti.us-east-1.rds.amazonaws.com',
                  PORT 5001,
                  DATABASE postgres,
                  USER postgres,
                  PASSWORD SECRET rds-instance-name_dbpass,
                  AWS PRIVATELINK privatelink_svc
              );
      EOT
}
```

Note: For MySQL instances, replace `POSTGRES` with `MYSQL` in the connection creation SQL, and adjust the `DATABASE` and `USER` fields accordingly.

### Output details: Configure Materialize

Once the Terraform module has been applied, you can configure Materialize to connect to the RDS instances using the PrivateLink endpoint:

- Connect to the Materialize instance using `psql`
- Run the SQL statement from the output of the `terraform apply` command to configure the PrivateLink connection, example:

```sql
CREATE CONNECTION privatelink_svc TO AWS PRIVATELINK (
        SERVICE NAME 'com.amazonaws.vpce.us-east-1.vpce-svc-1234567890abcdef0',
        AVAILABILITY ZONES ("use1-az1", "use1-az2")
    );
```

> Change the `privatelink_svc` to the name of the connection you want to use.

- Get the allowed principals for the VPC endpoint service

```sql
SELECT principal
    FROM mz_aws_privatelink_connections plc
    JOIN mz_connections c ON plc.id = c.id
    WHERE c.name = 'privatelink_svc';
```

- Add the allowed principals to the Endpoint Service configuration in the AWS console

- Finally, run the last SQL statement from the output of the `terraform apply` command to create the database connection which will use the PrivateLink endpoint. If you have multiple RDS instances, you will see multiple SQL statements:

For PostgreSQL instances:

```sql
-- Create the connection to the PostgreSQL RDS instance
CREATE CONNECTION pg_connection TO POSTGRES (
    HOST 'instance.foo000.us-west-1.rds.amazonaws.com',
    PORT 5432,
    DATABASE postgres,
    USER postgres,
    PASSWORD SECRET pgpass,
    AWS PRIVATELINK privatelink_svc
);
```

For MySQL instances:

```sql
-- Create the connection to the MySQL RDS instance
CREATE CONNECTION mysql_connection TO MYSQL (
    HOST 'mysql-instance.foo000.us-west-1.rds.amazonaws.com',
    PORT 3306,
    USER your_mysql_user,
    PASSWORD SECRET mysql_dbpass,
    AWS PRIVATELINK privatelink_svc
);
```

After that go to your AWS console and check that the VPC endpoint service has a pending connection request from the Materialize instance which you can approve.

After the connection request has been approved, you can create a database source in Materialize using the `pg_connection` or `mysql_connection` connection.

## Materialize Documentation

You can also follow the [Materialize documentation](https://materialize.com/docs/ops/network-security/privatelink/) for more information.
