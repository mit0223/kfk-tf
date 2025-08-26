resource "aws_s3_bucket" "input" {
  bucket = "${var.project_name}-input-bucket-${data.aws_caller_identity.current.account_id}"
  tags   = local.tags
}

resource "aws_s3_bucket" "output" {
  bucket = "${var.project_name}-output-bucket-${data.aws_caller_identity.current.account_id}"
  tags   = local.tags
}
