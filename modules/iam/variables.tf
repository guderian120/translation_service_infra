# modules/iam/variables.tf
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "input_bucket_arn" {
  description = "ARN of the input S3 bucket"
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of the output S3 bucket"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "arn of dynamo db"
  type = string
}