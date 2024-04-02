output "aws_state_bucket_id" {
  value = aws_s3_bucket.state_bucket.id
}

output "aws_state_bucket_arn" {
  value = aws_s3_bucket.state_bucket.arn
}

output "aws_state_bucket_name" {
  value = aws_s3_bucket.state_bucket.bucket
}

output "aws_state_bucket_region" {
  value = aws_s3_bucket.state_bucket.region
}

output "aws_locks_table_id" {
  value = aws_dynamodb_table.locks_table.id
}

output "aws_locks_table_arn" {
  value = aws_dynamodb_table.locks_table.arn
}

output "aws_locks_table_name" {
  value = aws_dynamodb_table.locks_table.name
}