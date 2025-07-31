# modules/api_gateway/outputs.tf
output "api_url" {
  value = "https://${aws_api_gateway_rest_api.translation_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/${aws_api_gateway_resource.upload_resource.path_part}"
}

output "api_execution_arn" {
  value = aws_api_gateway_rest_api.translation_api.execution_arn
}

output "api_gatway_id" {
  value = aws_api_gateway_rest_api.translation_api.id
  
}