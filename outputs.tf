output "s3_input_bucket_name" {
  description = "Name of the S3 input bucket"
  value       = aws_s3_bucket.input.bucket
}

output "s3_output_bucket_name" {
  description = "Name of the S3 output bucket"
  value       = aws_s3_bucket.output.bucket
}

output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.main.arn
}

output "producer_lambda_function_name" {
  description = "Name of the producer Lambda function"
  value       = aws_lambda_function.producer.function_name
}

output "consumer_lambda_function_name" {
  description = "Name of the consumer Lambda function"
  value       = aws_lambda_function.consumer.function_name
}
