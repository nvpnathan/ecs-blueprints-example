output "application_url" {
  value       = module.client_alb.lb_dns_name
  description = "Copy this value in your browser in order to access the deployed app"
}

