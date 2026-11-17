provider "aws" {
  region = "eu-north-1"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "tfstate-tpfinal-floreal-2026"   # nom unique au monde
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = "tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
