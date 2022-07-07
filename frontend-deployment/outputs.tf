output "application_url" {
  value       = module.client_alb.lb_dns_name
  description = "Copy this value in your browser in order to access the deployed app"
}

output "client_security_group" {
  value = module.client_task_security_group.security_group_id
  description = "Ingress source for backend application"
}