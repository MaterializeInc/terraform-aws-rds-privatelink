# Create a target group for the RDS instance
resource "aws_lb_target_group" "mz_rds_target_group" {
  name        = "mz-rds-tg-${substr(var.mz_rds_instance_name, 0, 22)}"
  port        = data.aws_db_instance.mz_rds_instance.port
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.mz_rds_vpc.id
  target_type = "ip"
}

# Attach a target to the target group
resource "aws_lb_target_group_attachment" "mz_rds_target_group_attachment" {
  target_group_arn = aws_lb_target_group.mz_rds_target_group.arn
  target_id        = data.dns_a_record_set.rds_ip.addrs[0]
}

# Create a network Load Balancer
resource "aws_lb" "mz_rds_lb" {
  name               = "mz-rds-lb-${var.mz_rds_instance_name}"
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
