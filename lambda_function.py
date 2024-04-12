import logging
import boto3
import socket
import os
import json

# Initialize clients
elbv2_client = boto3.client('elbv2')
rds_client = boto3.client('rds')

# Initialize logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Load RDS details from environment variables
RDS_DETAILS = json.loads(os.environ['RDS_DETAILS'])

def update_target_registration(rds_identifier, details):
    try:
        logger.info(f"Checking target registration for {rds_identifier}")
        # Retrieve the current IP address of the RDS instance
        rds_instances = rds_client.describe_db_instances(DBInstanceIdentifier=rds_identifier)
        rds_port = rds_instances['DBInstances'][0]['Endpoint']['Port']
        if not rds_instances['DBInstances']:
            logger.error(f"No instances found for {rds_identifier}")
            raise Exception(f"No instances found for {rds_identifier}")

        rds_endpoint = rds_instances['DBInstances'][0]['Endpoint']['Address']
        ip_address = socket.gethostbyname(rds_endpoint)

        # Retrieve the existing target of the target group
        target_group_arn = details['target_group_arn']
        targets = elbv2_client.describe_target_health(TargetGroupArn=target_group_arn)

        # Check and update the target group
        current_ip = targets['TargetHealthDescriptions'][0]['Target']['Id'] if targets['TargetHealthDescriptions'] else None
        if current_ip != ip_address:
            if current_ip:
                # Deregister the current target
                elbv2_client.deregister_targets(TargetGroupArn=target_group_arn, Targets=[{'Id': current_ip}])

            # Register the new target
            elbv2_client.register_targets(TargetGroupArn=target_group_arn, Targets=[{'Id': ip_address, 'Port': rds_port}])
            message = f"Target group {target_group_arn} updated. New target IP: {ip_address}"
        else:
            message = f"Target group {target_group_arn} already up to date. Current target IP: {ip_address} and Port: {rds_port}"

        logger.info(message)
        return {'success': True, 'message': message}
    except Exception as e:
        logger.error(f"Error updating target registration for {rds_identifier}: {e}")
        return {'success': False, 'message': f"Failed to update targets for {rds_identifier} with error: {e}"}

def lambda_handler(event, context):
    logger.info("Handler invoked")
    update_messages = []
    all_success = True

    for rds_identifier, details in RDS_DETAILS.items():
        result = update_target_registration(rds_identifier, details)
        update_messages.append(result['message'])
        if not result['success']:
            all_success = False
            logger.warning(f"Update failed for {rds_identifier}")

    status_code = 200 if all_success else 500
    logger.info(f"Function completed with status code {status_code}")

    return {
        'statusCode': status_code,
        'body': json.dumps(update_messages)
    }
