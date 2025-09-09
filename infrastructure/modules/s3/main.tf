# S3 Buckets
resource "aws_s3_bucket" "assets" {
  count  = var.create_assets_bucket ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-assets-${random_string.suffix.result}"
  tags   = var.tags
}

resource "aws_s3_bucket" "logs" {
  count  = var.create_logs_bucket ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-logs-${random_string.suffix.result}"
  tags   = var.tags
}

resource "aws_s3_bucket" "backups" {
  count  = var.create_backups_bucket ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-backups-${random_string.suffix.result}"
  tags   = var.tags
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "create_assets_bucket" {
  description = "Create assets bucket"
  type        = bool
  default     = true
}

variable "create_logs_bucket" {
  description = "Create logs bucket"
  type        = bool
  default     = true
}

variable "create_backups_bucket" {
  description = "Create backups bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags"
  type        = map(string)
  default     = {}
}

# Outputs
output "assets_bucket_id" {
  description = "Assets bucket ID"
  value       = var.create_assets_bucket ? aws_s3_bucket.assets[0].id : ""
}

output "assets_bucket_arn" {
  description = "Assets bucket ARN"
  value       = var.create_assets_bucket ? aws_s3_bucket.assets[0].arn : ""
}

output "logs_bucket_id" {
  description = "Logs bucket ID"
  value       = var.create_logs_bucket ? aws_s3_bucket.logs[0].id : ""
}

output "backups_bucket_id" {
  description = "Backups bucket ID"
  value       = var.create_backups_bucket ? aws_s3_bucket.backups[0].id : ""
}
