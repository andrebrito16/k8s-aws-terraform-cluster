resource "aws_secretsmanager_secret" "kubeconfig_secret" {
  name        = local.kubeconfig_secret_name
  description = "Kubeconfig k8s. Cluster name: ${var.cluster_name}, environment: ${var.environment}"

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.kubeconfig_secret_name}")
    }
  )
}

resource "aws_secretsmanager_secret" "kubeadm_ca" {
  name        = local.kubeadm_ca_secret_name
  description = "Kubeadm CA. Cluster name: ${var.cluster_name}, environment: ${var.environment}"

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.kubeadm_ca_secret_name}")
    }
  )
}

resource "aws_secretsmanager_secret" "kubeadm_token" {
  name        = local.kubeadm_token_secret_name
  description = "Kubeadm token. Cluster name: ${var.cluster_name}, environment: ${var.environment}"

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.kubeadm_token_secret_name}")
    }
  )
}

resource "aws_secretsmanager_secret" "kubeadm_cert" {
  name        = local.kubeadm_cert_secret_name
  description = "Kubeadm cert. Cluster name: ${var.cluster_name}, environment: ${var.environment}"

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.kubeadm_cert_secret_name}")
    }
  )
}

# secret default values

resource "aws_secretsmanager_secret_version" "kubeconfig_secret_default" {
  secret_id     = aws_secretsmanager_secret.kubeconfig_secret.id
  secret_string = var.default_secret_placeholder
}

resource "aws_secretsmanager_secret_version" "kubeadm_ca_default" {
  secret_id     = aws_secretsmanager_secret.kubeadm_ca.id
  secret_string = var.default_secret_placeholder
}

resource "aws_secretsmanager_secret_version" "kubeadm_token_default" {
  secret_id     = aws_secretsmanager_secret.kubeadm_token.id
  secret_string = var.default_secret_placeholder
}

resource "aws_secretsmanager_secret_version" "kubeadm_cert_default" {
  secret_id     = aws_secretsmanager_secret.kubeadm_cert.id
  secret_string = var.default_secret_placeholder
}

# Secret Policies

resource "aws_secretsmanager_secret_policy" "kubeconfig_secret_policy" {
  secret_arn = aws_secretsmanager_secret.kubeconfig_secret.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "${aws_iam_role.k8s_iam_role.arn}"
        },
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue"
        ]
        Resource = [
          "${aws_secretsmanager_secret.kubeconfig_secret.arn}"
        ]
      }
    ]
  })
}