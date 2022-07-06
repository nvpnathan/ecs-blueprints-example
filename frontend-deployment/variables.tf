variable "ecs_cluster_id" {
  description = "Core-infra ECS Cluster ID"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Core-infra ECS execution ARN"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "Core-infra ECS execution ARN"
  type        = string
}

variable "ecs_task_execution_role_name" {
  description = "Core-infra ECS execution role name"
  type        = string
}

variable "private_subnets" {
  description = "Core-infra shared public subnets list"
  type        = list
}

variable "private_subnets_cidr_blocks" {
  description = "Core-infra private subnet CIDR block list"
  type        = list
}

variable "public_subnets" {
  description = "Core-infra shared public subnets list"
  type        = list
}

variable "vpc_id" {
  description = "Core-infra VPC ID"
  type        = string
}

# Application Repo
variable "github_token" {
  description = "Personal access token from Github"
  type        = string
  sensitive   = true
}

variable "env_repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
  default     = "nvpnathan"
}

variable "env_repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "ecs-blueprints-example"
}

variable "env_repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "buildspec_path" {
  description = "The location of the buildspec file"
  type        = string
  default     = "../01/frontend-deployment/appconfig/buildspec_rolling.yml"
}

variable "folder_path_app" {
  description = "The location of the client files"
  type        = string
  default     = "$CODEBUILD_SRC_DIR"
}

variable "app_repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
  default     = "nvpnathan"
}

variable "app_repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "ecs-client-frontend"
}

variable "app_repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}
