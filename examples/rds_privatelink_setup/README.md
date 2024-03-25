# RDS + PrivateLink Setup Example

This example demonstrates how to create a new Amazon RDS Postgres instance and configure a PrivateLink endpoint for it to connect to Materialize using the provided Terraform module. This setup is intended for testing and development purposes.

## Prerequisites

- Terraform installed on your machine.
- An AWS account with permissions to create RDS instances, VPCs, PrivateLink endpoints, and related resources.
- AWS CLI configured with your credentials and default region.

## Setup Instructions

1. **Navigate to the Example Directory**

   Change into the `examples/rds_privatelink_setup` directory where this README is located.

   ```
   cd examples/rds_privatelink_setup
   ```

1. **Initialize Terraform**

   Run the Terraform init command to initialize the project, download required providers, and modules.

   ```
   terraform init
   ```

1. **Review the Terraform Plan**

   Execute the Terraform plan command to review the resources that will be created.

   ```
   terraform plan
   ```

1. **Apply the Terraform Configuration**

   Apply the Terraform configuration to create the RDS instance and set up the PrivateLink connection.

   ```
   terraform apply
   ```

   You'll need to confirm the action by typing `yes` when prompted.

1. Once the resources have been created, you can test the module with:

    ```hcl
    module "materialize_privatelink_rds" {
        source = "../.."

        mz_rds_instance_details = [
            { name = "instance1", listener_port = 5001 },
            { name = "instance2", listener_port = 5002 }
        ]
        mz_rds_vpc_id           = module.rds_postgres.vpc.vpc_id
        aws_region              = var.aws_region
    }
    ```

1. **Follow the Output Instructions**

   After Terraform successfully applies the configuration, it will output instructions for configuring the PrivateLink endpoint and the Postgres connections in Materialize. Follow these instructions to complete the setup.

## Cleanup

To remove all resources created by this example and avoid further charges, run:

```
terraform destroy
```

Confirm the action by typing `yes` when prompted.
