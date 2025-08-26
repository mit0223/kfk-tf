data "archive_file" "producer_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layers/producer"
  output_path = "${path.module}/producer_layer.zip"
}

resource "aws_lambda_layer_version" "producer_layer" {
  layer_name = "${var.project_name}-producer-layer"
  filename   = data.archive_file.producer_layer_zip.output_path
  source_code_hash = data.archive_file.producer_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9"]
}

data "archive_file" "consumer_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layers/consumer"
  output_path = "${path.module}/consumer_layer.zip"
}

resource "aws_lambda_layer_version" "consumer_layer" {
  layer_name = "${var.project_name}-consumer-layer"
  filename   = data.archive_file.consumer_layer_zip.output_path
  source_code_hash = data.archive_file.consumer_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9"]
}

data "archive_file" "producer_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/producer"
  output_path = "${path.module}/producer.zip"
}

resource "aws_lambda_function" "producer" {
  function_name = "${var.project_name}-producer-lambda"
  role          = aws_iam_role.producer_lambda.arn
  handler       = "main.handler"
  runtime       = "python3.9"
  timeout       = 30

  filename         = data.archive_file.producer_lambda_zip.output_path
  source_code_hash = data.archive_file.producer_lambda_zip.output_base64sha256

  layers = [aws_lambda_layer_version.producer_layer.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      BOOTSTRAP_SERVERS = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
      TOPIC_NAME        = "${var.project_name}-topic"
    }
  }

  tags = local.tags
}

data "archive_file" "consumer_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/consumer"
  output_path = "${path.module}/consumer.zip"
}

resource "aws_lambda_function" "consumer" {
  function_name = "${var.project_name}-consumer-lambda"
  role          = aws_iam_role.consumer_lambda.arn
  handler       = "main.handler"
  runtime       = "python3.9"
  timeout       = 30

  filename         = data.archive_file.consumer_lambda_zip.output_path
  source_code_hash = data.archive_file.consumer_lambda_zip.output_base64sha256

  layers = [aws_lambda_layer_version.consumer_layer.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.output.bucket
    }
  }

  tags = local.tags
}

# S3 bucket notification for producer lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.producer.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn
}

# MSK event source mapping for consumer lambda
resource "aws_lambda_event_source_mapping" "msk_trigger" {
  function_name = aws_lambda_function.consumer.arn
  topics        = ["${var.project_name}-topic"]
  batch_size    = 100

  event_source_arn = aws_msk_cluster.main.arn
}