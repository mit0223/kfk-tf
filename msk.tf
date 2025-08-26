resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project_name}-msk-cluster"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = length(var.private_subnet_cidrs)

  broker_node_group_info {
    instance_type   = var.kafka_broker_instance_type
    client_subnets  = aws_subnet.private[*].id
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  tags = local.tags
}

resource "aws_msk_configuration" "main" {
  kafka_versions = [var.kafka_version]
  name           = "${var.project_name}-msk-config"
  server_properties = <<-EOT
    auto.create.topics.enable = true
  EOT
}

resource "aws_msk_cluster_policy" "main" {
  cluster_arn = aws_msk_cluster.main.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.producer_lambda.arn
        }
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:WriteData",
          "kafka-cluster:CreateTopic"
        ]
        Resource = aws_msk_cluster.main.arn
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.consumer_lambda.arn
        }
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:ReadData"
        ]
        Resource = aws_msk_cluster.main.arn
      }
    ]
  })
}
