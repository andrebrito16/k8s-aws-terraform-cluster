locals {
  k8s_tls_san_public        = var.create_extlb && var.expose_kubeapi ? aws_lb.external_lb[0].dns_name : ""
  kubeconfig_secret_name    = "${var.common_prefix}-kubeconfig/${var.cluster_name}/${var.environment}/v1"
  kubeadm_ca_secret_name    = "${var.common_prefix}-kubeadm-ca/${var.cluster_name}/${var.environment}/v1"
  kubeadm_token_secret_name = "${var.common_prefix}-kubeadm-token/${var.cluster_name}/${var.environment}/v1"
  kubeadm_cert_secret_name  = "${var.common_prefix}-kubeadm-secret/${var.cluster_name}/${var.environment}/v1"
  global_tags = {
    environment      = "${var.environment}"
    provisioner      = "terraform"
    terraform_module = "https://github.com/garutilorenzo/k8s-aws-terraform-cluster"
    k8s_cluster_name = "${var.cluster_name}"
    application      = "k8s"
  }
}