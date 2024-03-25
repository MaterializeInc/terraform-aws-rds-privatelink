# Create a target group for each RDS instance
resource "aws_lb_target_group" "mz_rds_target_group" {
  for_each = { for inst in var.mz_rds_instance_details : inst.name => inst }

  name        = "${substr(each.key, 0, 12)}-${each.value.listener_port}-tg"
  port        = data.aws_db_instance.mz_rds_instance[each.key].port
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.mz_rds_vpc.id
  target_type = "ip"
}

# Attach a target to each target group
resource "aws_lb_target_group_attachment" "mz_rds_target_group_attachment" {
  for_each = { for inst in var.mz_rds_instance_details : inst.name => inst }

  target_group_arn = aws_lb_target_group.mz_rds_target_group[each.key].arn
  target_id        = data.dns_a_record_set.rds_ip[each.key].addrs[0]

  lifecycle {
    ignore_changes = [target_id]
  }
  depends_on = [aws_lb_target_group.mz_rds_target_group]
}

# Create a network Load Balancer
resource "aws_lb" "mz_rds_lb" {
  name                             = var.mz_nlb_name
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = values(data.aws_subnet.mz_rds_subnet)[*].id
  enable_cross_zone_load_balancing = var.cross_zone_load_balancing
  tags = {
    Name = "mz-rds-lb"
  }
}

# Create listeners for each RDS instance, mapping each to its respective target group
resource "aws_lb_listener" "mz_rds_listener" {
  for_each = { for inst in var.mz_rds_instance_details : inst.name => inst }

  load_balancer_arn = aws_lb.mz_rds_lb.arn
  port              = each.value.listener_port
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mz_rds_target_group[each.key].arn
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
  name               = "lambda_execution_${substr(var.mz_nlb_name, 0, 12)}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Create a Lambda function to check the RDS instance IP address
resource "aws_lambda_function" "check_rds_ip" {
  function_name = "${substr(var.mz_nlb_name, 0, 12)}-check-rds-ip"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  filename = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      RDS_DETAILS = jsonencode({for inst in var.mz_rds_instance_details : inst.name => {port = inst.listener_port, target_group_arn = aws_lb_target_group.mz_rds_target_group[inst.name].arn}})
    }
  }
}


# Create an IAM policy for the Lambda function
resource "aws_iam_role_policy" "lambda_execution_role_policy" {
  name   = "${substr(var.mz_nlb_name, 0, 12)}-lambda-execution-role-policy"
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
  name                = "${substr(var.mz_nlb_name, 0, 12)}-rds-ip-check-rule"
  description         = "Fires every ${var.schedule_expression} to check the RDS instance IP address"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "check_rds_ip_event_target" {
  rule      = aws_cloudwatch_event_rule.rds_ip_check_rule.name
  target_id = "${substr(var.mz_nlb_name, 0, 12)}-check-rds-ip"
  arn       = aws_lambda_function.check_rds_ip.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_rds_ip" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_rds_ip.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_ip_check_rule.arn
}
