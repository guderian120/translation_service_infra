# modules/sqs/variables.tf
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "lambda_translate_processor_arn" {
  description = "ARN of the upload handler lambda function"
  type        = string
}