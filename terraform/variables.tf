variable "region" {
  description = "AWS Region to deploy the Bedrock AgentCore runtime into."
  type        = string
  default     = "us-east-1"
}

variable "agent_runtime_name" {
  description = "Name for the Bedrock AgentCore runtime. Must start with a letter and use only alphanumeric characters or underscores."
  type        = string
  default     = "TutorialRuntime"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,47}$", var.agent_runtime_name))
    error_message = "agent_runtime_name must start with a letter, contain only letters, numbers, or underscores, and be 48 characters or fewer."
  }
}

variable "agent_runtime_description" {
  description = "Optional description for the Bedrock AgentCore runtime."
  type        = string
  default     = null
  nullable    = true
}

variable "container_image_uri" {
  description = "Fully qualified ECR image URI that the runtime should execute."
  type        = string
  default     = "286574326306.dkr.ecr.us-east-1.amazonaws.com/bedrock-agentcore:latest"
}

variable "environment_variables" {
  description = "Optional environment variables to inject into the container runtime."
  type        = map(string)
  default     = {}
}

variable "network_mode" {
  description = "Networking mode for the runtime. Use PUBLIC for internet-accessible endpoints or VPC for private networking."
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC"], var.network_mode)
    error_message = "network_mode must be either PUBLIC or VPC."
  }
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to associate with the runtime when network_mode is VPC."
  type        = list(string)
  default     = []
}

variable "vpc_subnet_ids" {
  description = "Subnet IDs to associate with the runtime when network_mode is VPC."
  type        = list(string)
  default     = []
}

variable "server_protocol" {
  description = "Optional protocol override for the runtime server. Valid values: HTTP, MCP, A2A."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.server_protocol == null || contains(["HTTP", "MCP", "A2A"], var.server_protocol)
    error_message = "server_protocol must be null or one of HTTP, MCP, or A2A."
  }
}

variable "custom_jwt_authorizer" {
  description = "Optional JWT authorizer configuration for securing the runtime."
  type = object({
    discovery_url    = string
    allowed_audience = list(string)
    allowed_clients  = list(string)
  })
  default  = null
  nullable = true
}

variable "iam_role_name" {
  description = "Optional override for the IAM role name that the runtime assumes. A name is generated from agent_runtime_name when unset."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags to apply to taggable resources created by this configuration."
  type        = map(string)
  default     = {}
}

variable "create_runtime_endpoint" {
  description = "Whether to create a managed Agent Runtime endpoint in addition to the runtime itself."
  type        = bool
  default     = true
}

variable "agent_runtime_endpoint_name" {
  description = "Optional override for the Agent Runtime endpoint name. Defaults to <agent_runtime_name>_endpoint."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.agent_runtime_endpoint_name == null || can(regex("^[A-Za-z][A-Za-z0-9_]{0,47}$", var.agent_runtime_endpoint_name))
    error_message = "agent_runtime_endpoint_name must start with a letter, contain only letters, numbers, or underscores, and be 48 characters or fewer."
  }
}

variable "agent_runtime_endpoint_description" {
  description = "Optional description to apply to the Agent Runtime endpoint."
  type        = string
  default     = null
  nullable    = true
}

variable "agent_runtime_endpoint_tags" {
  description = "Additional tags specific to the Agent Runtime endpoint resource."
  type        = map(string)
  default     = {}
}
