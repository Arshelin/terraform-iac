output "security_policy_name" {
  description = "Cloud Armor security policy name for web application"
  value       = var.enable_webapp_policy ? google_compute_security_policy.webapp[0].name : null
}

output "security_policy_self_link" {
  description = "Cloud Armor security policy self link for web application"
  value       = var.enable_webapp_policy ? google_compute_security_policy.webapp[0].self_link : null
}

output "argocd_security_policy_name" {
  description = "Cloud Armor security policy name for ArgoCD"
  value       = var.enable_argocd_policy ? google_compute_security_policy.argocd[0].name : null
}

output "argocd_security_policy_self_link" {
  description = "Cloud Armor security policy self link for ArgoCD"
  value       = var.enable_argocd_policy ? google_compute_security_policy.argocd[0].self_link : null
}
