# ─────────────────────────────────────────────────────────────
# MinhaTurma — Infraestrutura AWS com Terraform
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Estado remoto no S3 (recomendado para produção)
  backend "s3" {
    bucket = "minhaturma-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ── VPC ───────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "minhaturma-vpc"
  cidr    = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true  # custo-eficiente para dev/staging
}

# ── ECS Cluster (containers do backend) ───────────────────────
resource "aws_ecs_cluster" "main" {
  name = "minhaturma-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ── RDS PostgreSQL ────────────────────────────────────────────
resource "aws_db_instance" "postgres" {
  identifier        = "minhaturma-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"   # ajuste para produção
  allocated_storage = 20
  storage_encrypted = true

  db_name  = "minhaturma"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  skip_final_snapshot     = false
  deletion_protection     = true
  multi_az                = true  # alta disponibilidade em produção
}

resource "aws_db_subnet_group" "main" {
  name       = "minhaturma-db-subnet"
  subnet_ids = module.vpc.private_subnets
}

# ── ElastiCache Redis ─────────────────────────────────────────
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "minhaturma-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "minhaturma-redis-subnet"
  subnet_ids = module.vpc.private_subnets
}

# ── S3 (Armazenamento de mídia) ───────────────────────────────
resource "aws_s3_bucket" "media" {
  bucket = "minhaturma-media-${var.environment}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Cognito (Autenticação) ────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = "minhaturma-users"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  auto_verified_attributes = ["email"]
  mfa_configuration        = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"
  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "email profile openid"
  }
  attribute_mapping = {
    email    = "email"
    username = "sub"
    name     = "name"
    picture  = "picture"
  }
}

resource "aws_cognito_identity_provider" "facebook" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Facebook"
  provider_type = "Facebook"
  provider_details = {
    client_id        = var.facebook_app_id
    client_secret    = var.facebook_app_secret
    authorize_scopes = "email,public_profile"
    api_version      = "v18.0"
  }
  attribute_mapping = {
    email    = "email"
    username = "id"
    name     = "name"
  }
}

resource "aws_cognito_user_pool_client" "mobile" {
  name         = "minhaturma-mobile"
  user_pool_id = aws_cognito_user_pool.main.id

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["Google", "Facebook", "COGNITO"]
  callback_urls                        = ["minhaturma://callback"]
  logout_urls                          = ["minhaturma://logout"]

  token_validity_units {
    access_token  = "hours"
    refresh_token = "days"
  }
  access_token_validity  = 1
  refresh_token_validity = 30
}

# ── CloudFront (CDN para assets/mídia) ───────────────────────
resource "aws_cloudfront_distribution" "media_cdn" {
  enabled = true
  origin {
    domain_name = aws_s3_bucket.media.bucket_regional_domain_name
    origin_id   = "S3-minhaturma-media"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.media.cloudfront_access_identity_path
    }
  }
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-minhaturma-media"
    viewer_protocol_policy = "https-only"
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "media" {
  comment = "MinhaTurma media OAI"
}

# ── Security Groups ───────────────────────────────────────────
resource "aws_security_group" "rds" {
  name   = "minhaturma-rds-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_security_group" "redis" {
  name   = "minhaturma-redis-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_security_group" "ecs" {
  name   = "minhaturma-ecs-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 8000
    to_port     = 8000
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
