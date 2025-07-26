output "lambda_function_names" {
  description = "Names of all Lambda functions"
  value = {
    for k, lambda in aws_lambda_function.lambda : k => lambda.function_name
  }
}

output "lambda_function_arns" {
  description = "ARNs of all Lambda functions"
  value = {
    for k, lambda in aws_lambda_function.lambda : k => lambda.arn
  }
}


output "lambda_upload_function_invoke_arn" {
  description = "Invoke ARN of lambda functions"
  value       = { for k, lambda in aws_lambda_function.lambda : k => lambda.invoke_arn }
}
