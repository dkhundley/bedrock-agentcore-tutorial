terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.66.0"
    }
  }
}

# Configuring AWS for Bedrock AgentCore resources.
provider "aws" {
  region = var.region
}

# Retrieving account metadata for resource-scoped IAM statements.
data "aws_caller_identity" "current" {}

# Defining the assume-role policy for the runtime execution role.
data "aws_iam_policy_document" "agent_runtime_assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

# Deriving default names for IAM role and runtime endpoint when overrides are not provided.
locals {
  iam_role_name = coalesce(
    var.iam_role_name,
    "${lower(replace(var.agent_runtime_name, "_", "-"))}-runtime-role"
  )

  agent_runtime_endpoint_name = coalesce(
    var.agent_runtime_endpoint_name,
    "${var.agent_runtime_name}_endpoint"
  )
}

# Granting the runtime permission to pull from ECR, emit logs/traces, and call Bedrock models.
data "aws_iam_policy_document" "agent_runtime_ecr_access" {
  statement {
    sid    = "AllowPullFromECR"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogging"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:*:*:log-group:/aws/bedrock-agentcore/runtimes/*"]
  }

  statement {
    sid    = "AllowXRayTracing"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowBedrockModelInvocation"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]

    resources = [
      "arn:aws:bedrock:${var.region}::foundation-model/*",
      "arn:aws:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:model/*"
    ]
  }
}

# Creating the execution role the runtime will assume.
resource "aws_iam_role" "agent_runtime" {
  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.agent_runtime_assume_role.json

  tags = merge(
    var.tags,
    {
      "Name" = local.iam_role_name
    }
  )
}

# Attaching the inline policy that the runtime needs for ECR, logging, and Bedrock access.
resource "aws_iam_role_policy" "agent_runtime_ecr_access" {
  name   = "${var.agent_runtime_name}-ecr-access"
  role   = aws_iam_role.agent_runtime.id
  policy = data.aws_iam_policy_document.agent_runtime_ecr_access.json
}

# Provisioning the Bedrock AgentCore runtime with the provided container image and networking config.
resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = var.agent_runtime_name
  role_arn           = aws_iam_role.agent_runtime.arn
  description        = var.agent_runtime_description
  environment_variables = var.environment_variables

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.container_image_uri
    }
  }

  network_configuration {
    network_mode = var.network_mode

    dynamic "network_mode_config" {
      for_each = var.network_mode == "VPC" ? [1] : []

      content {
        security_groups = var.vpc_security_group_ids
        subnets         = var.vpc_subnet_ids
      }
    }
  }

  dynamic "protocol_configuration" {
    for_each = var.server_protocol == null ? [] : [var.server_protocol]

    content {
      server_protocol = protocol_configuration.value
    }
  }

  dynamic "authorizer_configuration" {
    for_each = var.custom_jwt_authorizer == null ? [] : [var.custom_jwt_authorizer]

    content {
      custom_jwt_authorizer {
        discovery_url    = authorizer_configuration.value.discovery_url
        allowed_audience = authorizer_configuration.value.allowed_audience
        allowed_clients  = authorizer_configuration.value.allowed_clients
      }
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition = var.network_mode != "VPC" || (
        length(var.vpc_security_group_ids) > 0 &&
        length(var.vpc_subnet_ids) > 0
      )
      error_message = "When network_mode is VPC, provide non-empty vpc_security_group_ids and vpc_subnet_ids."
    }
  }
}

# Optionally standing up an AgentCore endpoint that targets the newly created runtime.
resource "aws_bedrockagentcore_agent_runtime_endpoint" "this" {
  count = var.create_runtime_endpoint ? 1 : 0

  name                  = local.agent_runtime_endpoint_name
  agent_runtime_id      = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
  agent_runtime_version = aws_bedrockagentcore_agent_runtime.this.agent_runtime_version
  description           = var.agent_runtime_endpoint_description
  tags                  = merge(var.tags, var.agent_runtime_endpoint_tags)
}

# Exposing runtime identifiers for downstream tooling.
output "agent_runtime_id" {
  description = "Unique identifier for the Bedrock AgentCore runtime."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

# Exposing the runtime ARN for IAM policy references.
output "agent_runtime_arn" {
  description = "ARN for the Bedrock AgentCore runtime."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

# Exposing the runtime version so clients can align with deployed revisions.
output "agent_runtime_version" {
  description = "Current version for the Bedrock AgentCore runtime."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_version
}

# Exposing endpoint metadata when the optional endpoint is created.
output "agent_runtime_endpoint_name" {
  description = "Name of the managed runtime endpoint when created."
  value       = try(aws_bedrockagentcore_agent_runtime_endpoint.this[0].name, null)
}

output "agent_runtime_endpoint_arn" {
  description = "ARN of the managed runtime endpoint when created."
  value       = try(aws_bedrockagentcore_agent_runtime_endpoint.this[0].agent_runtime_endpoint_arn, null)
}
