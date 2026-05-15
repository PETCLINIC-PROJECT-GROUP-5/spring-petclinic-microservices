locals {
  services = [
    "config-server",
    "discovery-server",
    "customers-service",
    "vets-service",
    "visits-service",
    "genai-service",
    "api-gateway",
    "admin-server",
    "zipkin"
  ]
}

resource "aws_ecr_repository" "petclinic" {
  for_each             = toset(local.services)
  name                 = "petclinic/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "petclinic"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
