# modules/cognito/main.tf
resource "aws_cognito_user_pool" "translation_app" {
  name = "translation-app-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
}

resource "aws_cognito_user_pool_client" "app_client" {
  name = "translation-app-client"

  user_pool_id    = aws_cognito_user_pool.translation_app.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

   # Enable hosted UI for sign-in/sign-up
  callback_urls        = ["https://oauth.pstmn.io/v1/callback"] # Postman callback URL
  logout_urls         = ["https://oauth.pstmn.io/v1/callback"]  # Postman logout URL
  allowed_oauth_flows = ["code", "implicit"]
  allowed_oauth_scopes = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = ["COGNITO"]



}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "translation-app-dev"
  user_pool_id = aws_cognito_user_pool.translation_app.id
}