# modules/s3/outputs.tf
output "input_bucket_name" {
  value = aws_s3_bucket.input_bucket.id
}

output "output_bucket_name" {
  value = aws_s3_bucket.output_bucket.id
}

output "input_bucket_arn" {
  value = aws_s3_bucket.input_bucket.arn
}

output "output_bucket_arn" {
  value = aws_s3_bucket.output_bucket.arn
}

output "output_bucket_dns" {
  value = aws_s3_bucket.output_bucket.bucket_regional_domain_name
}