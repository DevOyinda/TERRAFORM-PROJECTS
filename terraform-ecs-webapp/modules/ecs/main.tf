resource "aws_ecs_cluster" "this" {
  name = "webapp-cluster"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "webapp-task"
  requires_compatibilities = ["EC2"] # OR FARGATE
  network_mode             = "awsvpc" # OR BRIDGE
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "webapp"
    image     = var.container_image
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    environment = [{
    name  = "PORT"
    value = "80"
  }]
  }])
}

resource "aws_ecs_service" "this" {
  name            = "webapp-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.security_group_id]
    # assign_public_ip = true only for FARGATE
  }

  depends_on = [aws_ecs_task_definition.this]
}


variable "execution_role_arn" {
  type = string
}
variable "task_role_arn" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_id" {
  type = string
}
variable "container_image" {
  type = string
  description = "Full URI of the container image to run"
}
