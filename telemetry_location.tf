# =============================================================================
# Telemetry Location: Unity Catalog External Location to telemetery data bucket
# =============================================================================

locals {
    uc_iam_role = "${var.telemetry_location_name}-access-role"
}

data "aws_caller_identity" "current" {}

# grab existing S3 bucket 
data "aws_s3_bucket" "bucket" {
  count  = var.telemetry_bucket_name != null ? 1 : 0
  bucket = "${var.telemetry_bucket_name}"
}

# assume role policy - allows databricks to assume the role created above - json pulled from databricks provider
data "databricks_aws_unity_catalog_assume_role_policy" "telemetry_unity_catalog_assume_role_policy" {
  count          = var.telemetry_bucket_name != null ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  role_name      = local.uc_iam_role
  external_id    = databricks_storage_credential.telemetry_storage_credential[0].aws_iam_role[0].external_id
}

# policy to allow the databricks workspace to access the telemetry data bucket + manage SNS + SQS for file events- json pulled from databricks provider
data "databricks_aws_unity_catalog_policy" "telemetry_unity_catalog_policy" {
  count          = var.telemetry_bucket_name != null ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  bucket_name    = data.aws_s3_bucket.bucket[0].bucket
  role_name      = local.uc_iam_role
}

# Create IAM policy from telemetry_unity_catalog_policy above
resource "aws_iam_policy" "telemetry_external_data_access" {
  count  = var.telemetry_bucket_name != null ? 1 : 0
  policy = data.databricks_aws_unity_catalog_policy.telemetry_unity_catalog_policy[0].json
  tags = merge({
    Name = "${var.telemetry_location_name}-unity-catalog external access IAM policy"
  })
}

# Create a dedicated IAM role to access the telemetry data bucket + manage SNS + SQS for file events - uses assume role policy above
resource "aws_iam_role" "telemetry_access_role" {
  count              = var.telemetry_bucket_name != null ? 1 : 0
  name               = "${var.telemetry_location_name}-access-role"
  description        = "Role for accessing the telemetry data bucket"
  assume_role_policy = data.databricks_aws_unity_catalog_assume_role_policy.telemetry_unity_catalog_assume_role_policy[0].json
  tags = {
    Name = "${var.telemetry_location_name} Access Role"
  }
}

# attach the telemetry_external_data_access IAM policy to the role
resource "aws_iam_role_policy_attachment" "telemetry_access_role_policy_attachment" {
  count      = var.telemetry_bucket_name != null ? 1 : 0
  role       = aws_iam_role.telemetry_access_role[0].name
  policy_arn = aws_iam_policy.telemetry_external_data_access[0].arn
  depends_on = [aws_iam_role.telemetry_access_role]
}

# create a databricks storage credential from the IAM Role access_role created above
resource "databricks_storage_credential" "telemetry_storage_credential" {
  count    = var.telemetry_bucket_name != null ? 1 : 0
  provider = databricks.dev_workspace
  name     = "${var.telemetry_location_name}-credential"
  //cannot reference aws_iam_role directly, as it will create circular dependency
  aws_iam_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.uc_iam_role}"
  }
  comment       = "Managed by TF"
  force_destroy = true
  depends_on = [
    module.dev_workspace.databricks_host # requires workspace to be created first
  ]
}

# Create external location for the S3 bucket with file events enabled - uses storage credential created above
resource "databricks_external_location" "telemetry_location" {
  count           = var.telemetry_bucket_name != null ? 1 : 0
  provider        = databricks.dev_workspace
  name            = "${var.telemetry_location_name}"
  url             = "s3://${data.aws_s3_bucket.bucket[0].bucket}"
  credential_name = databricks_storage_credential.telemetry_storage_credential[0].id
  comment         = "External location for telemetry data"
  read_only       = true
  force_destroy   = true
  skip_validation = true
  enable_file_events = true
  file_event_queue {
    managed_sqs {} # databricks will create the SQS queue for file events
  }

  depends_on = [
    databricks_storage_credential.telemetry_storage_credential,
    data.aws_s3_bucket.bucket,
    aws_iam_role_policy_attachment.telemetry_access_role_policy_attachment,
    module.dev_workspace.databricks_host # requires workspace to be created first
  ]
}
