# modules/s3/variables.tf
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "lambda_upload_handler_arn" {
  description = "ARN of the upload handler lambda function"
  type        = string
}

variable "allowed_origins" {
  description = "List of domains allowed to access the bucket via CORS"
  type        = list(string)
  default     = ["*"]
}

variable "allowed_referers" {
  description = "List of referer patterns allowed to access the bucket"
  type        = list(string)
  default     = [
    "*",
  ]
}