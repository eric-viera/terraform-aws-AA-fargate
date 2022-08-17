resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "bridge"
  requires_compatibilities = [var.launch_type]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn
  container_definitions    = var.container_definitions_json
}

resource "aws_ecs_service" "main" {
  name                               = "${var.service_name}-service"
  cluster                            = var.cluster
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = var.launch_type
  scheduling_strategy                = var.launch_type == "FARGATE" ? "REPLICA" : var.strategy

  # this block is not compatible with tasks using bridge network_mode so it's commented
  # network_configuration {
  #   security_groups  = [aws_security_group.ecs_tasks.id]
  #   subnets          = var.private_subnets
  #   assign_public_ip = false
  # }

  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = "${var.service_name}-container"
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

}

resource "aws_alb_target_group" "main" {
  name        = "${var.service_name}-tg"
  port        = var.container_port
  protocol    = var.target_group_protocol
  vpc_id      = var.vpc_id
  # target_type = "ip"
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = var.listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }

  condition {
    host_header {
      values = ["${var.project_name}-${var.service_name}.${var.domain}"]
    }
  }
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.service_name}-task-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol         = "tcp"
    from_port        = var.container_port
    to_port          = var.container_port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_route53_record" "record" {
  zone_id = var.zone_id
  name    = "${var.project_name}-${var.service_name}.${var.domain}"
  type    = "CNAME"
  ttl     = 5
  records = [var.lb_dns_name]
}
