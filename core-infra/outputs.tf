output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "A list of public subnets"
  value       = module.vpc.public_subnets
}
output "private_subnets" {
  description = "A list of private subnets for the client app"
  value       = module.vpc.private_subnets
}

output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "ecs_task_execution_role_name" {
  description = "The ARN of the task execution role"
  value       = aws_iam_role.ecs_task_excecution_role.name
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the task execution role"
  value       = aws_iam_role.ecs_task_excecution_role.arn
}
