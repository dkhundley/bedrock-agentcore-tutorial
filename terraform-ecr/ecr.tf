terraform {
	required_version = ">= 1.5.0"

	required_providers {
		aws = {
			source  = "hashicorp/aws"
			version = "~> 5.0"
		}
	}
}

provider "aws" {
	region = "us-east-1"
}

resource "aws_ecr_repository" "agentcore" {
	name                 = "bedrock-agentcore"
	image_tag_mutability = "MUTABLE"

	encryption_configuration {
		encryption_type = "AES256"
	}

	image_scanning_configuration {
		scan_on_push = true
	}
}

output "ecr_repository_url" {
	description = "URL of the created ECR repository"
	value       = aws_ecr_repository.agentcore.repository_url
}
