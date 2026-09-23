locals {
  ssm_prefix = "/terraform-k8s"
}

# Generated during apply, never stored in plan or state; bump the version to rotate.
ephemeral "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  name             = "${local.ssm_prefix}/grafana/admin-password"
  description      = "Grafana admin password, consumed by External Secrets"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.grafana_admin.result
  value_wo_version = 1
  tags             = local.default_tags
}
