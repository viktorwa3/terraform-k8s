locals {
  ssm_prefix = "/terraform-k8s"
}

# Ephemeral + write-only: the password is generated during apply, written to SSM,
# and never lands in the Terraform plan or state. Bump the version to rotate it.
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
