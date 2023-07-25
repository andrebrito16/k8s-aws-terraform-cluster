resource "aws_iam_instance_profile" "k8s_instance_profile" {
  name = "${var.common_prefix}-ec2-instance-profile--${var.environment}"
  role = aws_iam_role.k8s_iam_role.name

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-ec2-instance-profile--${var.environment}")
    }
  )
}

resource "aws_iam_role" "k8s_iam_role" {
  name = "${var.common_prefix}-iam-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-iam-role-${var.environment}")
    }
  )
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.common_prefix}-cluster-autoscaler-policy-${var.environment}"
  path        = "/"
  description = "Cluster autoscaler policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplateVersions"
        ],
        Resource = [
          "${aws_launch_template.k8s_server.arn}",
          "${aws_launch_template.k8s_worker.arn}"
        ],
        Condition = {
          StringEquals = {
            for tag, value in local.global_tags : "aws:ResourceTag/${tag}" => value
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:DescribeTags",
        ],
        Resource = [
          "${aws_autoscaling_group.k8s_servers_asg.arn}",
          "${aws_autoscaling_group.k8s_workers_asg.arn}"
        ],
        Condition = {
          StringEquals = {
            for tag, value in local.global_tags : "aws:ResourceTag/${tag}" => value
          }
        }
      },
    ]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-cluster-autoscaler-policy-${var.environment}")
    }
  )
}

resource "aws_iam_policy" "aws_efs_csi_driver_policy" {
  count       = var.efs_persistent_storage ? 1 : 0
  name        = "${var.common_prefix}-csi-driver-policy-${var.environment}"
  path        = "/"
  description = "AWS EFS CSI driver policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ],
        Resource = [
          "*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint"
        ],
        Resource = [
          "*"
        ],
        Condition = {
          StringLike = {
            "aws:RequestTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:TagResource"
        ],
        Resource = [
          "*"
        ],
        Condition = {
          StringLike = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DeleteAccessPoint"
        ],
        Resource = [
          "*"
        ],
        Condition = {
          StringEquals = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
    ]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-csi-driver-policy-${var.environment}")
    }
  )
}

resource "aws_iam_policy" "allow_secrets_manager" {
  name        = "${var.common_prefix}-secrets-manager-policy-${var.environment}"
  path        = "/"
  description = "Secrets Manager Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue"
        ],
        Resource = [
          "${aws_secretsmanager_secret.kubeconfig_secret.arn}",
          "${aws_secretsmanager_secret.kubeadm_ca.arn}",
          "${aws_secretsmanager_secret.kubeadm_token.arn}",
          "${aws_secretsmanager_secret.kubeadm_cert.arn}"
        ],
        Condition = {
          StringEquals = {
            for tag, value in local.global_tags : "aws:ResourceTag/${tag}" => value
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ],
        Resource = [
          "*"
        ],
      }
    ]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-secrets-manager-policy-${var.environment}")
    }
  )
}

resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.k8s_iam_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_role_policy_attachment" "attach_cluster_autoscaler_policy" {
  role       = aws_iam_role.k8s_iam_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

resource "aws_iam_role_policy_attachment" "attach_aws_efs_csi_driver_policy" {
  count      = var.efs_persistent_storage ? 1 : 0
  role       = aws_iam_role.k8s_iam_role.name
  policy_arn = aws_iam_policy.aws_efs_csi_driver_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_allow_secrets_manager_policy" {
  role       = aws_iam_role.k8s_iam_role.name
  policy_arn = aws_iam_policy.allow_secrets_manager.arn
}

resource "aws_iam_role_policy_attachment" "attach_ec2_ro_policy" {
  role       = aws_iam_role.k8s_iam_role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ReadOnlyAccess.arn
}