import boto3
import socket
import os

# Define the clients at the top of your function
elbv2_client = boto3.client('elbv2')
rds_client = boto3.client('rds')

RDS_IDENTIFIER = os.environ['RDS_IDENTIFIER']  # RDS instance identifier
TARGET_GROUP_ARN = os.environ['TARGET_GROUP_ARN']  # Target Group ARN


def lambda_handler(event, context):
    # Retrieve the current IP address of the RDS instance
    rds_instances = rds_client.describe_db_instances(
        DBInstanceIdentifier=RDS_IDENTIFIER)
    rds_endpoint = rds_instances['DBInstances'][0]['Endpoint']['Address']
    ip_address = socket.gethostbyname(rds_endpoint)
    rds_port = rds_instances['DBInstances'][0]['Endpoint']['Port']

    # Retrieve the existing target of the target group
    targets = elbv2_client.describe_target_health(
        TargetGroupArn=TARGET_GROUP_ARN)

    # Get the current IP address in the target group
    if targets['TargetHealthDescriptions']:
        current_ip = targets['TargetHealthDescriptions'][0]['Target']['Id']
    else:
        current_ip = None

    # If the IP addresses don't match, update the target group
    if current_ip and current_ip != ip_address:
            # Deregister the current target
            elbv2_client.deregister_targets(
                TargetGroupArn=TARGET_GROUP_ARN,
                Targets=[
                    {
                        'Id': current_ip
                    },
                ]
            )

            # Register the new target
            elbv2_client.register_targets(
                TargetGroupArn=TARGET_GROUP_ARN,
                Targets=[
                    {
                        'Id': ip_address,
                        'Port': rds_port
                    },
                ]
            )

    return {
        'statusCode': 200,
        'body': f'Target group updated. Current target IP: {ip_address}'
    }
