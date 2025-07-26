# modules/lambda/variables.tf
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "upload_handler_zip_path" {
  description = "Path to the upload handler Lambda zip file"
  type        = string
}

variable "translation_processor_zip_path" {
  description = "Path to the translation processor Lambda zip file"
  type        = string
}

variable "input_bucket_name" {
  description = "Name of the input S3 bucket"
  type        = string
  
}


variable "dynamodb_table_name" {
  description = "ARN of the DynamoDB table"
  type        = string
  
}
variable "sqs_queue_url" {
  description = "URL of the SQS queue"
  type        = string
}

variable "output_bucket_name" {
  description = "Name of the output S3 bucket"
  type        = string
}
variable "iam_role" {
  description = "Iam role for lambda"
}

