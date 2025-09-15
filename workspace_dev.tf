# =============================================================================================
# Workspace Setup: Dev Environment
# =============================================================================================
provider "databricks" {
  alias      = "dev_workspace"
  host       = module.dev_workspace.databricks_host
  account_id = var.databricks_account_id
  
  # Authenticate using environment variables: https://registry.terraform.io/providers/databricks/databricks/latest/docs#argument-reference
  # export DATABRICKS_CLIENT_ID=CLIENT_ID
  # export DATABRICKS_CLIENT_SECRET=CLIENT_SECRET
}


module "dev_workspace" {
  source = "./modules/workspace_setup"

  providers = {
    databricks.mws               = databricks.mws
    databricks.created_workspace = databricks.dev_workspace
    aws                          = aws
  }

  # Dependencies from account level setup
  metastore_id                    = databricks_metastore.this.id
  admin_user                      = var.admin_user
  aws_account_id                  = var.aws_account_id
  databricks_account_id           = var.databricks_account_id
  region                          = var.region
  telemetry_location_name         = var.telemetry_bucket_name != null ? databricks_external_location.telemetry_location[0].name : null
  telemetry_bucket_name           = var.telemetry_bucket_name
  account_groups                  = databricks_group.groups

  #variables per workspace 
  resource_prefix                 = "byam-dev" #name of the workspace
  vpc_cidr_range                  = "10.0.0.0/18"
  private_subnets_cidr            = ["10.0.0.0/22", "10.0.4.0/22"]
  public_subnets_cidr             = ["10.0.12.0/22", "10.0.16.0/22"]
  telemetry_bucket_env_prefix     = "dev"
  databricks_gov_shard            = null
}

#workspace specific outputs
output "dev_workspace_url" {
  value       = module.dev_workspace.databricks_host
  description = "Databricks workspace URL"
}

output "dev_workspace_service_principal_id" {
  value       = module.dev_workspace.service_principal_application_id
  description = "Service principal application ID for the workspace"
}

