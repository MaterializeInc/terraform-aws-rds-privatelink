# Contributor instructions

## Testing

### Manual testing

To test the module manually, follow these steps:

1. Login to the [AWS console](https://aws.amazon.com/).
1. Create an [Amazon RDS instance](https://aws.amazon.com/rds/).
1. Copy the `terraform.tfvars.example` file to `terraform.tfvars`:
    ```
    cp terraform.tfvars.example terraform.tfvars
    ```
1. Update the values in `terraform.tfvars` to match your cluster.
1. Create the resources:
    ```
    terraform apply
    ```
1. After the resources have been created, go to the Target Groups in the AWS console and make sure that the health checks are passing. If they are not, you will need to add the subnet CIDR blocks of your RDS instance to the security groups of your RDS instance. For more information, see [this AWS documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-troubleshooting.html).
1. Next, run the queries in the output to create the connection in Materialize.
1. Finally, in your AWS console, under the Endpoint Service that was created, approve the connection request from the Materialize instance and check that the connection is active.
1. You can now create a Postgres/MySQL source in Materialize using the connection name from the output.
1. Finally, drop the connection in Materialize and run `terraform destroy` to clean up the resources.

## Cutting a new release

Perform a manual test of the latest code on `main`. See prior section. Then run:

    git tag -a vX.Y.Z -m vX.Y.Z
    git push origin vX.Y.Z
