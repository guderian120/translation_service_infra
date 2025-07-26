# variables.tf
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "translation-app"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}