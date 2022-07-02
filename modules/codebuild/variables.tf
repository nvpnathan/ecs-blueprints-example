variable "name" {
  type        = string
  description = "CodeBuild Project name"
}

variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}

variable "iam_role" {
  type        = string
  description = "IAM role to attach to CodeBuild"
}

variable "ecr_repo_url" {
  description = "AWS ECR repository URL where docker images are being stored"
  type        = string
}

variable "folder_path" {
  description = "Folder path to use to build the docker images/containers"
  type        = string
}

variable "buildspec_path" {
  description = "Path to for the Buildspec file"
  type        = string
}

variable "task_definition_family" {
  description = "The family name of the Task definition"
  type        = string
}

variable "container_name" {
  description = "The name of the Container specified in the Task definition"
  type        = string
}

variable "service_port" {
  description = "The number of the port used by the ECS Service"
  type        = number
}

variable "ecs_role" {
  description = "The name of the ECS Task Excecution role to specify in the Task Definition"
  type        = string
}

variable "ecs_task_role" {
  description = "The name of the ECS Task role to specify in the Task Definition"
  type        = string
  default     = "null"
}

