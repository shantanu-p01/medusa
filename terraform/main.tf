provider "aws" {
  region = "ap-northeast-1"
}

# VPC
resource "aws_vpc" "medusa_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "medusa-vpc"
  }
}

# Subnets (creating two for high availability)
resource "aws_subnet" "medusa_subnet_1" {
  vpc_id = aws_vpc.medusa_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "medusa-subnet-1"
  }
}

resource "aws_subnet" "medusa_subnet_2" {
  vpc_id = aws_vpc.medusa_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "medusa-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "medusa_igw" {
  vpc_id = aws_vpc.medusa_vpc.id
  
  tags = {
    Name = "medusa-igw"
  }
}

# Route Table
resource "aws_route_table" "medusa_rt" {
  vpc_id = aws_vpc.medusa_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.medusa_igw.id
  }
  
  tags = {
    Name = "medusa-route-table"
  }
}

# Route Table Associations
resource "aws_route_table_association" "medusa_rta_1" {
  subnet_id = aws_subnet.medusa_subnet_1.id
  route_table_id = aws_route_table.medusa_rt.id
}

resource "aws_route_table_association" "medusa_rta_2" {
  subnet_id = aws_subnet.medusa_subnet_2.id
  route_table_id = aws_route_table.medusa_rt.id
}

# Security Group
resource "aws_security_group" "medusa_sg" {
  name        = "medusa-security-group"
  description = "Allow inbound traffic for Medusa application"
  vpc_id      = aws_vpc.medusa_vpc.id
  
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow access to Medusa backend"
  }
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow access to PostgreSQL"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "medusa-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name = "medusa-cluster"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "medusa_logs" {
  name = "/ecs/medusa"
  retention_in_days = 14
  
  tags = {
    Application = "Medusa"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-tasks"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "2048"  # 2 vCPU
  memory                   = "4096"  # 4GB
  execution_role_arn       = "arn:aws:iam::767398105317:role/ecsTaskExecutionRole"
  
  container_definitions = jsonencode([
    {
      name = "medusa_postgres"
      image = "postgres:latest"
      cpu = 512
      memory = 1024
      portMappings = [
        {
          name = "postgres-5432-tcp"
          containerPort = 5432
          hostPort = 5432
          protocol = "tcp"
          appProtocol = "http"
        }
      ]
      essential = true
      environment = [
        {
          name = "POSTGRES_USER"
          value = "medusa"
        },
        {
          name = "POSTGRES_PASSWORD"
          value = "medusa"
        },
        {
          name = "POSTGRES_DB"
          value = "medusa"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group" = "/ecs/medusa"
          "awslogs-region" = "ap-northeast-1"
          "awslogs-stream-prefix" = "postgres"
        }
      }
    },
    {
      name = "medusa_backend"
      image = "shantanupatil01/medusa:latest"
      cpu = 1024
      memory = 2048
      dependsOn = [
        {
          containerName = "medusa_postgres"
          condition = "START"
        }
      ]
      portMappings = [
        {
          name = "backend-9000-tcp"
          containerPort = 9000
          hostPort = 9000
          protocol = "tcp"
          appProtocol = "http"
        }
      ]
      essential = true
      environment = [
        {
          name = "PORT"
          value = "9000"
        },
        {
          name = "NODE_ENV"
          value = "production"
        },
        {
          name = "DATABASE_URL"
          value = "postgres://medusa:medusa@localhost:5432/medusa"
        },
        {
          name = "COOKIE_SECRET"
          value = "supersecret"
        },
        {
          name = "JWT_SECRET"
          value = "supersecret"
        },
        {
          name = "SEED_DATABASE"
          value = "true"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group" = "/ecs/medusa"
          "awslogs-region" = "ap-northeast-1"
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])
  
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  
  tags = {
    Name = "medusa-task-definition"
  }
}

# ECS Service
resource "aws_ecs_service" "medusa_service" {
  name             = "medusa-service"
  cluster          = aws_ecs_cluster.medusa_cluster.id
  task_definition  = aws_ecs_task_definition.medusa_task.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets          = [aws_subnet.medusa_subnet_1.id, aws_subnet.medusa_subnet_2.id]
    security_groups  = [aws_security_group.medusa_sg.id]
    assign_public_ip = true
  }
  
  lifecycle {
    ignore_changes = [desired_count]
  }
  
  tags = {
    Name = "medusa-service"
  }
}