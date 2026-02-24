variable "aws_region"   { default = "us-east-1" }
variable "environment"  { default = "production" }
variable "db_username"  { sensitive = true }
variable "db_password"  { sensitive = true }
variable "google_client_id"     { sensitive = true }
variable "google_client_secret" { sensitive = true }
variable "facebook_app_id"      { sensitive = true }
variable "facebook_app_secret"  { sensitive = true }
