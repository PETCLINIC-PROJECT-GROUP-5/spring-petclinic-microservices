terraform {
  backend "s3" {
    bucket         = "petclinic-group5-tfstate"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "petclinic-tf-lock"
    encrypt        = true
    profile        = "dmi-group5"
  }
}
