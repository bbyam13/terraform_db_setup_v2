# =============================================================================================
# Workspace Setup: Prod Environment
# =============================================================================================
provider "databricks" {
  alias      = "prod_workspace"
  host       = module.prod_workspace.databricks_host #this must match the module name
  account_id = var.databricks_account_id
  
  # Authenticate using environment variables: https://registry.terraform.io/providers/databricks/databricks/latest/docs#argument-reference
  # export DATABRICKS_CLIENT_ID=CLIENT_ID
  # export DATABRICKS_CLIENT_SECRET=CLIENT_SECRET
}


module "prod_workspace" {
  source = "./modules/workspace_setup"

  providers = {
    databricks.mws               = databricks.mws
    databricks.created_workspace = databricks.prod_workspace #this must match the alias in the provider block
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
  resource_prefix                 = "byam-prod" #name of the workspace
  vpc_cidr_range                  = "10.0.0.0/18"
  private_subnets_cidr            = ["10.0.0.0/22", "10.0.4.0/22"]
  public_subnets_cidr             = ["10.0.12.0/22", "10.0.16.0/22"]
  sg_egress_ports                 = ["80", "53", "443", "2443", "6666", "8443", "8444", "8445", "8446", "8447", "8448", "8449", "8450", "8451"]
  telemetry_bucket_env_prefix     = "prod"
  databricks_gov_shard            = null
}

#workspace specific outputs
output "prod_workspace_url" {
  value       = module.prod_workspace.databricks_host #update this to match the module name
  description = "Databricks workspace URL"
}

output "prod_workspace_service_principal_id" {
  value       = module.prod_workspace.service_principal_application_id #update this to match the module name
  description = "Service principal application ID for the workspace"
}

