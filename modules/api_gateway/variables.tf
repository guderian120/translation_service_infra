variable "input_bucket_name" {
  description = "Name of the input S3 bucket"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string

}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "lambda_upload_function_invoke_arn" {
  description = "invoke arn of lambda put"
  type = string
}
variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  type        = string

}

variable "lambda_api_key_function_invoke_arn" {
  description = "value of lambda api key function invoke arn"
  type = string
}

variable "lambda_api_key_function_name" {
  description = "lambda function name for api key"
  type = string
  
}

variable "lambda_upload_function_name" {
  description = "lambda function name"
  type = string
}
variable "output_bucket_name" {
  description = "Name of the output S3 bucket"
  type        = string
  
}

variable "lambda_get_user_uploads_invoke_arn" {
  description = "invoke arn of lambda get user uploads"
  type = string
  
}
variable "lambda_get_user_uploads_function_name" {
  description = "lambda function name for get user uploads"
  type = string
  
}