terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "network" {
  source   = "../../modules/network"
  name     = "prod"
  vpc_cidr = var.vpc_cidr
  azs      = var.azs
}

resource "aws_security_group" "alb" {
  name   = "prod-alb-sg"
  vpc_id = module.network.vpc_id

  ingress {
    description = "Internet to ALB"
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

resource "aws_security_group" "ecs" {
  name   = "prod-ecs-sg"
  vpc_id = module.network.vpc_id

  ingress {
    description     = "ALB to ECS"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name   = "prod-rds-sg"
  vpc_id = module.network.vpc_id

  ingress {
    description     = "ECS to RDS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_lb" "app" {
  name               = "prod-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.network.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "app" {
  name        = "prod-app-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.network.vpc_id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

module "ecs" {
  source             = "../../modules/ecs"
  name               = "prod"
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [aws_security_group.ecs.id]
  target_group_arn   = aws_lb_target_group.app.arn
  cpu                = var.ecs_cpu
  memory             = var.ecs_memory
  desired_count      = var.ecs_desired_count

  depends_on = [aws_lb_listener.http]
}

module "rds" {
  source              = "../../modules/rds"
  name                = "prod"
  subnet_ids          = module.network.private_subnet_ids
  security_group_ids  = [aws_security_group.rds.id]
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  backup_retention    = var.db_backup_retention
  deletion_protection = var.db_deletion_protection
  db_password         = var.db_password
}
