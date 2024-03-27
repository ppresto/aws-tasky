resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.bucket_name}"  # Replace with your desired bucket name
  
  tags = {
    Name        = "MongoS3Bucket"
    Service     = "mongo-backup"
  }
  
}
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.my_bucket.id
  rule {
    object_ownership = var.bucket_ownership_controls
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.my_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


# resource "aws_s3_bucket_policy" "my_bucket_policy" {
#   bucket = aws_s3_bucket.my_bucket.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = "*",
#         Action = ["s3:GetObject","s3:PutObject","s3:PutObjectAcl","s3:DeleteObject"],
#         Resource = "${aws_s3_bucket.my_bucket.arn}/*",  # Allow access to all objects within the bucket
#       },
#     ],
#   })
#   depends_on = [ aws_s3_bucket_public_access_block.block_public_access ]
# }
