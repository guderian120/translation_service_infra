# outputs.tf
output "api_url" {
  value = module.api_gateway.api_url
}

output "input_bucket_name" {
  value = module.s3.input_bucket_name
}

output "output_bucket_name" {
  value = module.s3.output_bucket_name
}

output "cognito_signup_url" {
  value = module.cognito.signup_url
}

output "cognito_signin_url" {
  value = module.cognito.signin_url
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

output "api_key_url" {
  value = "${module.api_gateway.api_base_url}/api_keys"
}
output "api_base_url" {
  value = module.api_gateway.api_base_url
}
output "cognito_domain" {
  value = module.cognito.domain
}
output "user_pool_id" {
  value = module.cognito.user_pool_id
  
}

output "output_bucket_dns"{
  value = module.s3.output_bucket_dns
}