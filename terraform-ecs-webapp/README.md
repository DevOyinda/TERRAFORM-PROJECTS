# Hosting a Dynamic Web App on AWS with Terraform Module, Docker, Amazon ECR, and ECS

I used Terraform to create a modular infrastructure for hosting a dynamic web app on Amazon ECS. I containerized the web app using Docker, pushed the Docker image to Amazon ECR, and deployed the app on ECS.

> 🔧 For this project, I built only the backend using Node.js — no frontend (client-side) interface was developed.

---

## Task 1: Dockerization of Web App

1. I created a dynamic web application using Node.js by doing the following:

2. Created a directory `webapp` and navigated into it:

```bash
mkdir webapp
cd webapp
```
3. Initialized Node.js backend (server-side) project & Installed express.js framework for backend functionality:

```bash
npm init -y
npm install express
```

4. Created `app.js` and added backend server logic:
```bash
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Hello, World! This is a Dockerized web app.');
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
```
5. Tested the application locally:
`node app.js`

![](./Images/1.%20node.js%20server.png)

![](./Images/2.%20local%20host%203000.png)

6. Created a Dockerfile to containerize the app:
```bash
# Use the official Node.js image from Docker Hub
FROM node:18

# Set working directory
WORKDIR /usr/src/app

# Copy dependencies metadata
COPY package*.json ./

# Install app dependencies
RUN npm install

# Copy application source
COPY . .

# Expose the port
EXPOSE 3000

# Run the application
CMD ["node", "app.js"]
```

7. Built and ran the Docker image:
```bash
docker build -t webapp .
docker run -p 3000:3000 webapp
```
![](./Images/3.%20docker%20run.png)

## Task 2: Terraform Module for Amazon ECR

Created modular infrastructure for ECR and ECS in `terraform-ecs-webapp/modules/ecr&ecs/main.tf`

### `modules/ecr/main.tf`

```hcl
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

variable "repository_name" {
  type = string
  description = "Name of the ECR repository"
}
```
## Task 3: Terraform Module for Amazon ECS
### `modules/ecs/main.tf`

```bash
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
```
`### terraform-ecs-webapp/main.tf`
```bash
provider "aws" {
  region = "us-east-1"
}

#  ECR Module
module "ecr" {
  source          = "./modules/ecr"
  repository_name = "webapp-repo"
}

#  ECS Module
module "ecs" {
  source              = "./modules/ecs"
  container_image     = "${module.ecr.repository_url}:latest"
  execution_role_arn  = aws_iam_role.ecs_execution_role.arn
  task_role_arn       = aws_iam_role.ecs_task_role.arn
  subnet_ids          = data.aws_subnets.selected.ids # Replace with actual subnet IDs
  security_group_id   = aws_security_group.ecs_sg.id
}

#  IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}



#  Get default VPC and public subnets
data "aws_vpc" "selected" {
  default = true
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

#  Create a security group
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow HTTP inbound"
  vpc_id      = data.aws_vpc.selected.id # Replace with your VPC ID

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 LAUNCH TEMPLATE
resource "aws_launch_template" "ecs" {
  name_prefix   = "ecs-instance-"
  image_id      = "ami-xxxx" # ECS-optimized AMI (adjust for region)
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=webapp-cluster >> /etc/ecs/ecs.config
              EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs_sg.id]
  }
}

# AUTOSCALING GROUP
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  vpc_zone_identifier = data.aws_subnets.selected.ids

  tag {
    key                 = "Name"
    value               = "ECS Instance"
    propagate_at_launch = true
  }
}
```
## Task 4: Build and push Docker image to ECR

Tagged the Docker image for ECR:

```bash
docker tag my-image:latest aws_account_id.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest
```
Replace:

`my-image` with your image name

`aws_account_id` with your actual AWS Account ID

`my-repo` with your ECR repository name

Pushed the Docker image to ECR:
```bash
docker push aws_account_id.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest
```

## Task 5: Ran Terraform commands to provision infrastructure:
```bash
terraform init
terraform plan
terraform apply
```
![](./Images/4.%20terraform%20apply%20created.png)

ECR & ECS created
![](./Images/5.%20ECR%20created.png)
![](./Images/6.%20ECS%20created.png)