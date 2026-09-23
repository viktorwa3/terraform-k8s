data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.app_name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = local.default_tags
}

# Read-only on this project's parameters; the aws/ssm key needs no kms:Decrypt.
data "aws_iam_policy_document" "node_ssm_read" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.location}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*",
    ]
  }
}

resource "aws_iam_role_policy" "node_ssm_read" {
  name   = "ssm-read-${var.app_name}"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node_ssm_read.json
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.app_name}-node"
  role = aws_iam_role.node.name
  tags = local.default_tags
}
