output "environment" {
  value = var.environment
}

output "postgres_endpoint" {
  value       = aws_db_instance.postgres.address
  description = "RDS Postgres hostname"
}

output "postgres_port" {
  value = aws_db_instance.postgres.port
}

output "database_secret_arn" {
  value       = aws_secretsmanager_secret.database_url.arn
  description = "Secrets Manager ARN for RAPHAEL_DATABASE_URL"
}

output "jwt_secret_arn" {
  value       = aws_secretsmanager_secret.jwt_secret.arn
  description = "Secrets Manager ARN for RAPHAEL_JWT_SECRET"
}

output "artifacts_bucket" {
  value       = aws_s3_bucket.artifacts.bucket
  description = "S3 bucket for artifact blobs (MinIO equivalent in AWS)"
}

output "ops_backups_bucket" {
  value       = aws_s3_bucket.ops_backups.bucket
  description = "S3 bucket for ops backups"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.raphael.name
}

output "gateway_service_name" {
  value = aws_ecs_service.raphael_core.name
}
