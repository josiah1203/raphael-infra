terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket = "raphael-terraform-state"
    key    = "staging/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "database_url" {
  name = "${var.project}-${var.environment}-database-url"
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = var.db_name
    url      = "postgresql://${var.db_username}:${random_password.db_password.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}"
  })
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "${var.project}-${var.environment}-jwt-secret"
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

resource "random_password" "jwt_secret" {
  length  = 48
  special = true
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project}-${var.environment}-postgres"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_security_group" "postgres" {
  name        = "${var.project}-${var.environment}-postgres"
  description = "Postgres access for Raphael staging"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier                 = "${var.project}-${var.environment}-postgres"
  engine                     = "postgres"
  engine_version             = "16.4"
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage_gb
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = random_password.db_password.result
  db_subnet_group_name       = aws_db_subnet_group.postgres.name
  vpc_security_group_ids     = [aws_security_group.postgres.id]
  skip_final_snapshot        = var.environment != "production"
  publicly_accessible        = false
  storage_encrypted          = true
  backup_retention_period    = 7
  auto_minor_version_upgrade = true
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project}-${var.environment}-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "ops_backups" {
  bucket = "${var.project}-${var.environment}-ops-backups-${data.aws_caller_identity.current.account_id}"
}

resource "aws_ecs_cluster" "raphael" {
  name = "${var.project}-${var.environment}"
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/ecs/${var.project}-${var.environment}/raphael-core"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "services" {
  name              = "/ecs/${var.project}-${var.environment}/services"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "raphael_core" {
  family                   = "${var.project}-${var.environment}-core"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "raphael-core"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/raphael-core:${var.environment}"
      essential = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      environment = [
        { name = "RAPHAEL_LOG_FORMAT", value = "json" },
        { name = "RAPHAEL_PUBLIC_API_BASE", value = "https://api.staging.raphael.app" },
      ]
      secrets = [
        { name = "RAPHAEL_JWT_SECRET", valueFrom = aws_secretsmanager_secret.jwt_secret.arn },
        { name = "RAPHAEL_DATABASE_URL", valueFrom = "${aws_secretsmanager_secret.database_url.arn}:url::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.gateway.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "core"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    },
  ])
}

resource "aws_ecs_service" "raphael_core" {
  name            = "${var.project}-${var.environment}-core"
  cluster         = aws_ecs_cluster.raphael.id
  task_definition = aws_ecs_task_definition.raphael_core.arn
  desired_count   = var.gateway_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.services.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_security_group" "services" {
  name        = "${var.project}-${var.environment}-services"
  description = "Raphael ECS services"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project}-${var.environment}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-${var.environment}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${var.project}-${var.environment}-secrets-read"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
      ]
      Resource = [
        aws_secretsmanager_secret.database_url.arn,
        "${aws_secretsmanager_secret.database_url.arn}:*",
        aws_secretsmanager_secret.jwt_secret.arn,
        "${aws_secretsmanager_secret.jwt_secret.arn}:*",
        aws_s3_bucket.artifacts.arn,
        "${aws_s3_bucket.artifacts.arn}/*",
        aws_s3_bucket.ops_backups.arn,
        "${aws_s3_bucket.ops_backups.arn}/*",
      ]
    }]
  })
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
