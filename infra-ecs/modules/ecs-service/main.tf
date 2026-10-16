# ecs-service module - one shop service: log group, execution role, task def, service

# one group per service so crashed tasks are findable without grepping others
resource "aws_cloudwatch_log_group" "infra_ecs_cloudwatch" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.name_prefix}-${var.service_name}-logs"
  }
}

# who the ECS agent acts as when pulling the image and writing logs.
# per-service, not shared: one shared role would let every task pull every
# repo and write every log group
resource "aws_iam_role" "infra_ecs_iam_role" {
  name = "${var.service_name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.name_prefix}-${var.service_name}-execution"
  }
}

# managed policy covers the two agent actions before app code runs: ECR pull and logs write
resource "aws_iam_role_policy_attachment" "infra_ecs_iam_role_policy_attachment" {
  role       = aws_iam_role.infra_ecs_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# family is the deployable unit: the service always tracks its latest ACTIVE revision
resource "aws_ecs_task_definition" "infra_ecs_task_def" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu                = var.cpu
  memory             = var.memory
  execution_role_arn = aws_iam_role.infra_ecs_iam_role.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.image
      essential = true
      portMappings = [
        {
          # this name is what Service Connect looks up, not the number
          name          = var.port_name
          containerPort = var.container_port
          appProtocol   = var.app_protocol
        }
      ]
      # ECS wants a list of objects; the variable is a map, so convert it
      environment = [
        for k, v in var.environment : {
          name  = k
          value = v
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.infra_ecs_cloudwatch.name
          awslogs-region        = var.region
          awslogs-stream-prefix = var.service_name
        }
      }
    }
  ])

  tags = {
    Name = "${var.name_prefix}-${var.service_name}-taskdef"
  }
}

# the running unit: keeps desired_count copies of the task alive in this cluster
resource "aws_ecs_service" "infra_ecs_service" {
  name            = var.service_name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.infra_ecs_task_def.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # explicit: AWS can move the platform version forward on new deployments
  platform_version = "LATEST"

  # awsvpc tasks cannot launch without this; private subnets, no public IP
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }

  # registers the service under the namespace and opens the dial path;
  # port_name must match the port mapping name or traffic blackholes
  service_connect_configuration {
    enabled   = true
    namespace = var.namespace_arn

    service {
      discovery_name = var.service_name
      port_name      = var.port_name

      client_alias {
        dns_name = var.service_name
        port     = var.container_port
      }
    }
  }

  # a deploy that cannot reach steady state stops itself and reverts, instead
  # of crash-looping tasks forever at zero healthy
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # frontend only: renders for a TG arn, renders nothing for backends
  dynamic "load_balancer" {
    for_each = var.alb_target_group_arn != null ? [var.alb_target_group_arn] : []

    content {
      target_group_arn = load_balancer.value
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  # grace period only makes sense with a load balancer watching; null-safe,
  # backends get the attribute unset instead of a zero default
  health_check_grace_period_seconds = var.alb_target_group_arn != null ? 90 : null
}