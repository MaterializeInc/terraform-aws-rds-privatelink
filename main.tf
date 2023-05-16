# Create a target group for the RDS instance
resource "aws_lb_target_group" "mz_rds_target_group" {
  name        = "mz-rds-${substr(var.mz_rds_instance_name, 0, 12)}-tg"
  port        = data.aws_db_instance.mz_rds_instance.port
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.mz_rds_vpc.id
  target_type = "ip"
}

# Attach a target to the target group
resource "aws_lb_target_group_attachment" "mz_rds_target_group_attachment" {
  target_group_arn = aws_lb_target_group.mz_rds_target_group.arn
  target_id        = data.dns_a_record_set.rds_ip.addrs[0]
  lifecycle {
    ignore_changes = [target_id]
  }
}

# Create a network Load Balancer
resource "aws_lb" "mz_rds_lb" {
  name               = "mz-rds-${substr(var.mz_rds_instance_name, 0, 12)}-lb"
  internal           = true
  load_balancer_type = "network"
  subnets            = values(data.aws_subnet.mz_rds_subnet)[*].id
  tags = {
    Name = "mz-rds-lb"
  }
}

# Create a tcp listener on the Load Balancer for the RDS instance
resource "aws_lb_listener" "mz_rds_listener" {
  load_balancer_arn = aws_lb.mz_rds_lb.arn
  port              = data.aws_db_instance.mz_rds_instance.port
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mz_rds_target_group.arn
  }
}

# Create VPC endpoint service for the Load Balancer
resource "aws_vpc_endpoint_service" "mz_rds_lb_endpoint_service" {
  acceptance_required        = var.mz_acceptance_required
  network_load_balancer_arns = [aws_lb.mz_rds_lb.arn]
  tags = {
    Name = "mz-rds-lb-endpoint-service"
  }
}

# Create an IAM policy for the Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_execution_${substr(var.mz_rds_instance_name, 0, 12)}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Create a Lambda function to check the RDS instance IP address
resource "aws_lambda_function" "check_rds_ip" {
  function_name = "${substr(var.mz_rds_instance_name, 0, 12)}-check-rds-ip"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  filename = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      RDS_IDENTIFIER   = var.mz_rds_instance_name
      TARGET_GROUP_ARN = aws_lb_target_group.mz_rds_target_group.arn
    }
  }
}

# Create an IAM policy for the Lambda function
resource "aws_iam_role_policy" "lambda_execution_role_policy" {
  name   = "${substr(var.mz_rds_instance_name, 0, 12)}-lambda-execution-role-policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "rds:DescribeDBInstances",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_rule" "rds_ip_check_rule" {
  name                = "${substr(var.mz_rds_instance_name, 0, 12)}-rds-ip-check-rule"
  description         = "Fires every ${var.schedule_expression} to check the RDS instance IP address"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "check_rds_ip_event_target" {
  rule      = aws_cloudwatch_event_rule.rds_ip_check_rule.name
  target_id = "${substr(var.mz_rds_instance_name, 0, 12)}-check-rds-ip"
  arn       = aws_lambda_function.check_rds_ip.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_rds_ip" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_rds_ip.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_ip_check_rule.arn
}
