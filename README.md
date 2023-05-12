# Materialize + PrivateLink + RDS

> **Warning**
> This is provided on a best-effort basis and Materialize cannot offer support for this module

This repository contains a Terraform module that configures a PrivateLink endpoint for an existing Amazon RDS Postgres database to connect to Materialize.

The module creates the following resources:
- Target group for the RDS instance
- Network Load Balancer for the RDS instance
- TCP listener for the NLB to forward traffic to the target group
- A VPC endpoint service for your RDS instance

## Important Remarks

> **Note**
> The RDS instance needs to be private. If your RDS instance is public, there is no need to use PrivateLink.

- The RDS instance must be in the same VPC as the PrivateLink endpoint.
- Review this module with your Cloud Security team to ensure that it meets your security requirements.
- Finally, after the Terraform module has been applied, you will need to make sure that the Target Groups heatlth checks are passing. As the NLB does not have security groups, you will need to make sure that the NLB is able to reach the RDS instance by allowing the subnet CIDR blocks in the security groups of the RDS instance.

To override the default AWS provider variables, you can export the following environment variables:

```bash
export AWS_PROFILE=<your_aws_profile> # eg. default
export AWS_CONFIG_FILE=<your_aws_config_file> # eg. ["~/.aws/config"]
```

## Usage

### Variables

Start by copying the `terraform.tfvars.example` file to `terraform.tfvars` and filling in the variables:

```
cp terraform.tfvars.example terraform.tfvars
```

| Name | Description | Type | Example | Required |
|------|-------------|:----:|:-----:|:-----:|
| mz_rds_instance_name | The name of the RDS instance | string | `'my-rds-instance'` | yes |
| mz_rds_vpc_id | The VPC ID of the RDS instance | string | `'vpc-1234567890abcdef0'` | yes |
| mz_acceptance_required | Whether or not to require manual acceptance of new connections | bool | `true` | no |

### Apply the Terraform Module

```
terraform apply
```

### Output

After the Terraform module has been applied, you will see the following output.

You can follow the instructions in the output to configure the PrivateLink endpoint and the Postgres connection in Materialize:

```sql
  - mz_rds_endpoint_sql             = <<-EOT
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

            -- IMPORTANT: Get the allowed principals, then add them to the VPC endpoint service

            -- Create the connection to the RDS instance
            CREATE CONNECTION pg_connection TO POSTGRES (
                HOST 'instance.foo000.us-west-1.rds.amazonaws.com',
                PORT 5432,
                DATABASE postgres,
                USER postgres,
                PASSWORD SECRET pgpass,
                AWS PRIVATELINK privatelink_svc
            );
    EOT
```

### Output details: Configure Materialize

Once the Terraform module has been applied, you can configure Materialize to connect to the RDS instance using the PrivateLink endpoint:

- Connect to the Materialize instance using `psql`
- Run the SQL statement from the output of the `terraform apply` command to configure the PrivateLink connection, example:

```sql
CREATE CONNECTION privatelink_svc TO AWS PRIVATELINK (
        SERVICE NAME 'com.amazonaws.vpce.us-east-1.vpce-svc-1234567890abcdef0',
        AVAILABILITY ZONES ("use1-az1", "use1-az2")
    );
```

- Get the allowed principals for the VPC endpoint service

```sql
SELECT principal
    FROM mz_aws_privatelink_connections plc
    JOIN mz_connections c ON plc.id = c.id
    WHERE c.name = 'privatelink_svc';
```

- Add the allowed principals to the Endpoint Service configuration in the AWS console

- Finally, run the last SQL statement from the output of the `terraform apply` command to create the Postgres connection which will use the PrivateLink endpoint, example:

```sql
-- Create the connection to the RDS instance
CREATE CONNECTION pg_connection TO POSTGRES (
    HOST 'instance.foo000.us-west-1.rds.amazonaws.com',
    PORT 5432,
    DATABASE postgres,
    USER postgres,
    PASSWORD SECRET pgpass,
    AWS PRIVATELINK privatelink_svc
);
```

After that go to your AWS console and check that the VPC endpoint service has a pending connection request from the Materialize instance which you can approve.

After the connection request has been approved, you can create a Postgres source in Materialize using the `pg_connection` connection.

## Materialize Documentation

You can also follow the [Materialize documentation](https://materialize.com/docs/ops/network-security/privatelink/) for more information.
