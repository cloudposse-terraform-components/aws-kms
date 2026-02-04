locals {
  account_id        = data.aws_caller_identity.current.account_id
  account_principal = "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:root"

  principals = sort(distinct(concat(
    var.allowed_principal_arns,
    module.allowed_role_map.principals,
  )))
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

module "allowed_role_map" {
  source = "github.com/cloudposse-terraform-components/aws-account-map//src/modules/roles-to-principals?ref=v1.536.1"

  privileged = false
  role_map   = var.allowed_roles

  tenant      = var.account_map_enabled ? module.iam_roles.global_tenant_name : null
  environment = var.account_map_enabled ? module.iam_roles.global_environment_name : null
  stage       = var.account_map_enabled ? module.iam_roles.global_stage_name : null

  account_map_bypass   = !var.account_map_enabled
  account_map_defaults = var.account_map

  context = module.this.context
}

module "kms_key" {
  source  = "cloudposse/kms-key/aws"
  version = "0.12.2"

  alias                    = var.alias == null ? "alias/${module.this.id}" : var.alias
  description              = var.description == null ? "${module.this.id} KMS Key. Managed by Terraform." : var.description
  deletion_window_in_days  = var.deletion_window_in_days
  enable_key_rotation      = var.enable_key_rotation
  key_usage                = var.key_usage
  customer_master_key_spec = var.customer_master_key_spec
  multi_region             = var.multi_region

  policy = var.policy != "" ? var.policy : data.aws_iam_policy_document.key_policy.json

  context = module.this.context
}

data "aws_iam_policy_document" "key_policy" {

  statement {
    sid    = "KeyAdministration"
    effect = "Allow"

    actions = [
      "kms:*",
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_principal]
    }
  }

  # Only create the "KeyUsage" statement if there are any principals
  dynamic "statement" {
    for_each = length(local.principals) > 0 ? [1] : []
    content {
      sid    = "KeyUsage"
      effect = "Allow"

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]

      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.principals
      }
    }
  }

  dynamic "statement" {
    for_each = var.additional_statements

    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "principals" {
        for_each = statement.value.principals

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}
