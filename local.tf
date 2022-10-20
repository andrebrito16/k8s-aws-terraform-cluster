locals {
  kubeconfig_secret_name    = "${var.common_prefix}-kubeconfig/${var.cluster_name}/${var.environment}/v1"
  kubeadm_ca_secret_name    = "${var.common_prefix}-kubeadm-ca/${var.cluster_name}/${var.environment}/v1"
  kubeadm_token_secret_name = "${var.common_prefix}-kubeadm-token/${var.cluster_name}/${var.environment}/v1"
  kubeadm_cert_secret_name  = "${var.common_prefix}-kubeadm-secret/${var.cluster_name}/${var.environment}/v1"
  global_tags = {
    environment      = "${var.environment}"
    provisioner      = "terraform"
    terraform_module = "https://github.com/garutilorenzo/k8s-aws-terraform-cluster"
    k3s_cluster_name = "${var.cluster_name}"
    application      = "k8s"
  }
}