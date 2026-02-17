# Resource Block: Random String
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Resource Block: AWS S3 Bucket
resource "aws_s3_bucket" "demo_bucket" {
  bucket = "devopsdemo-${random_string.bucket_suffix.result}"
  tags = {
    Name        = "devopsdemo-${random_string.bucket_suffix.result}"
    Environment = "Dev"

  }

}
