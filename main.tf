terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
    }
  }
}



provider "aws" {
  region  = var.region
  profile = "sandbox"
}

module "s3" {
  source                    = "./modules/s3"
  prefix                    = var.prefix
  lambda_upload_handler_arn = module.lambda.lambda_function_arns["translation_put_file"]
 
 }

module "sqs" {
  source                         = "./modules/sqs"
  prefix                         = var.prefix
  lambda_translate_processor_arn =  module.lambda.lambda_function_arns["translation_process_event"]
}

module "iam" {
  source            = "./modules/iam"
  prefix            = var.prefix
  input_bucket_arn  = module.s3.input_bucket_arn
  output_bucket_arn = module.s3.output_bucket_arn
  sqs_queue_arn     = module.sqs.queue_arn
  dynamodb_table_arn = module.dynamodb.dynamodb_table_arn
}

module "lambda" {
  source                         = "./modules/lambda"
  prefix                         = var.prefix
  upload_handler_zip_path        = "${path.module}/lambda_functions/upload_handler/main.zip"
  translation_processor_zip_path = "${path.module}/lambda_functions/translation_processor/main.zip"
  sqs_queue_url                  = module.sqs.queue_url
  output_bucket_name             = module.s3.output_bucket_name
  iam_role                       = module.iam.lambda_role_arn 
  input_bucket_name              = module.s3.input_bucket_name
  dynamodb_table_name            = module.dynamodb.dynamodb_table_name   

}

module "api_gateway" {
  source                = "./modules/api_gateway"
  prefix                = var.prefix
  region                = var.region
  input_bucket_name     = module.s3.input_bucket_name
  cognito_user_pool_arn = module.cognito.user_pool_arn 
  output_bucket_name = module.s3.output_bucket_name 
  lambda_upload_function_invoke_arn = module.lambda.lambda_upload_function_invoke_arn["translation_put_file"]
  lambda_upload_function_name = module.lambda.lambda_function_names["translation_put_file"]
}


module "cognito" {
  source = "./modules/cognito"

}

module "dynamodb" {
  source = "./modules/dynamodb"

}