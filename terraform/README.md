# Raphael Staging Terraform

Staging skeleton for Postgres (RDS), S3 object storage, Secrets Manager, and ECS Fargate for `raphael-core`.

## Prerequisites

- AWS account with default VPC
- S3 bucket `raphael-terraform-state` for remote state (create once manually)
- ECR repositories for service images (push from CI)

## Usage

```bash
cd terraform
terraform init
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

## Outputs

After apply, wire these into service task definitions or Kubernetes secrets:

- `database_secret_arn` → `RAPHAEL_DATABASE_URL`
- `jwt_secret_arn` → `RAPHAEL_JWT_SECRET`
- `artifacts_bucket` → `RAPHAEL_S3_BUCKET` / ops MinIO replacement
- `postgres_endpoint` → tier-1 service Postgres connections

Core domain services (identity, workspaces, audit, graph, orgs) reuse the same RDS instance with shared migrations from `raphael-contracts`.
