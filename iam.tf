data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Common policy for Lambda logging
resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.project_name}-lambda-logging-policy"
  description = "IAM policy for logging from a lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# Common policy for Lambda VPC access
resource "aws_iam_policy" "lambda_vpc_access" {
  name        = "${var.project_name}-lambda-vpc-access-policy"
  description = "IAM policy for lambda functions to access VPC"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Role for Producer Lambda
resource "aws_iam_role" "producer_lambda" {
  name = "${var.project_name}-producer-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "producer_lambda_logging" {
  role       = aws_iam_role.producer_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "producer_lambda_vpc_access" {
  role       = aws_iam_role.producer_lambda.name
  policy_arn = aws_iam_policy.lambda_vpc_access.arn
}

resource "aws_iam_policy" "s3_read_access" {
  name        = "${var.project_name}-s3-read-policy"
  description = "Policy to allow reading from the input S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.input.arn,
          "${aws_s3_bucket.input.arn}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "producer_s3_read" {
  role       = aws_iam_role.producer_lambda.name
  policy_arn = aws_iam_policy.s3_read_access.arn
}

resource "aws_iam_policy" "msk_write_access" {
  name        = "${var.project_name}-msk-write-policy"
  description = "Policy to allow writing to the MSK cluster"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kafka-cluster:Connect"
        ]
        Effect   = "Allow"
        Resource = aws_msk_cluster.main.arn
      },
      {
        Action = [
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:CreateTopic"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.main.cluster_name}/*"
      },
      {
        Action = [
            "kafka-cluster:GetBootstrapBrokers"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "producer_msk_write" {
  role       = aws_iam_role.producer_lambda.name
  policy_arn = aws_iam_policy.msk_write_access.arn
}

# Role for Consumer Lambda
resource "aws_iam_role" "consumer_lambda" {
  name = "${var.project_name}-consumer-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "consumer_lambda_logging" {
  role       = aws_iam_role.consumer_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "consumer_lambda_vpc_access" {
  role       = aws_iam_role.consumer_lambda.name
  policy_arn = aws_iam_policy.lambda_vpc_access.arn
}

resource "aws_iam_policy" "s3_write_access" {
  name        = "${var.project_name}-s3-write-policy"
  description = "Policy to allow writing to the output S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.output.arn}/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "consumer_s3_write" {
  role       = aws_iam_role.consumer_lambda.name
  policy_arn = aws_iam_policy.s3_write_access.arn
}

resource "aws_iam_policy" "msk_read_access" {
  name        = "${var.project_name}-msk-read-policy"
  description = "Policy to allow reading from the MSK topic"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Effect   = "Allow"
        Resource = aws_msk_cluster.main.arn
      },
      {
        "Effect": "Allow",
        "Action": [
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:ReadData"
        ],
        "Resource": "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.main.cluster_name}/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "kafka-cluster:DescribeGroup"
        ],
        "Resource": "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/${aws_msk_cluster.main.cluster_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "consumer_msk_read" {
  role       = aws_iam_role.consumer_lambda.name
  policy_arn = aws_iam_policy.msk_read_access.arn
}

# The AWSLambdaMSKExecutionRole managed policy provides the necessary permissions 
# for the Lambda function to read from an MSK topic.
resource "aws_iam_role_policy_attachment" "consumer_msk_execution_role" {
  role       = aws_iam_role.consumer_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaMSKExecutionRole"
}
