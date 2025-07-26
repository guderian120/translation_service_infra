output "user_pool_arn" {
  value = aws_cognito_user_pool.translation_app.arn

}


output "signup_url" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com/signup?client_id=${aws_cognito_user_pool_client.app_client.id}&response_type=code&scope=email+openid+profile&redirect_uri=https://oauth.pstmn.io/v1/callback"
}

output "signin_url" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.app_client.id}&response_type=code&scope=email+openid+profile&redirect_uri=https://oauth.pstmn.io/v1/callback"
}

output "user_pool_id" {
  value = aws_cognito_user_pool.translation_app.id
}

output "client_id" {
  value = aws_cognito_user_pool_client.app_client.id
}

output "domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
}