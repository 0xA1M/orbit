# bucket name as AWS sees it
output "s3_bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.orbit_tfstate_bucket.id
}

# used later by IAM policies that need to read this bucket
output "s3_bucket_arn" {
  description = "The ARN of the bucket. Will be of format arn:aws:s3:::bucketname"
  value       = aws_s3_bucket.orbit_tfstate_bucket.arn
}
