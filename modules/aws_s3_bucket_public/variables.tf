variable "bucket_name" {
  description = "Unique name to identify all resources. Try using your name."
  type        = string
  default     = "pp-s3-backup"
}


variable "bucket_ownership_controls" {
  description = "S3 bucket ownership controls. BucketOwnerPreferred or ObjectWriter"
  type        = string
  default     = "BucketOwnerPreferred"
}

