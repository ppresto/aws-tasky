resource "aws_s3_bucket" "my_bucket" {
  bucket        = "${var.bucket_name}"
  force_destroy = true
  tags = {
    Name        = "MongoS3Bucket"
    Service     = "mongo-backup"
  }
}
resource "aws_s3_bucket_ownership_controls" "standard" {
  bucket = aws_s3_bucket.my_bucket.id
  rule {
    object_ownership = var.bucket_ownership_controls
  }
}
# Publically accessible S3 bucket
# https://s3.console.aws.amazon.com/s3/buckets/ext-mongodb-s3-backup
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.my_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.my_bucket.id
  policy = data.aws_iam_policy_document.allow_access.json
}

data "aws_iam_policy_document" "allow_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.my_bucket.arn,
      "${aws_s3_bucket.my_bucket.arn}/*",
    ]
  }
}