
locals {
  telemetry_storage_url = var.telemetry_bucket_name != null ? "s3://${var.telemetry_bucket_name}/${var.telemetry_bucket_env_prefix}" : null
}

# Create telemetry volume in the raw schema - maps to the telemetry data bucket prefix for the environment
resource "databricks_volume" "telemetry_volume" {
  count            = var.telemetry_bucket_name != null ? 1 : 0
  provider         = databricks.created_workspace
  name             = "telemetry"
  catalog_name     = module.unity_catalog_catalog_creation.workspace_catalog.name
  schema_name      = "raw"
  volume_type      = "EXTERNAL"
  storage_location = local.telemetry_storage_url
  comment          = "Telemetry data"
  depends_on = [
   module.unity_catalog_metastore_assignment,
   var.telemetry_location_name, 
   module.unity_catalog_catalog_creation, 
   module.databricks_mws_workspace
  ]
}

# Create telemetry metadata volume in the raw schema - store checkpoint data, schemas, etc. from the telemetry data
resource "databricks_volume" "telemetry_metadata_volume" {
  count            = var.telemetry_bucket_name != null ? 1 : 0
  provider         = databricks.created_workspace
  name             = "telemetry_metadata"
  catalog_name     = module.unity_catalog_catalog_creation.workspace_catalog.name
  schema_name      = "raw"
  volume_type      = "MANAGED" #will use the catalog's managed location for storage - see catalog_location.tf
  comment          = "Telemetry metadata"
  depends_on = [
    module.restrictive_root_bucket,
    databricks_grants.raw_access,
    module.unity_catalog_metastore_assignment,
    module.unity_catalog_catalog_creation,
    module.databricks_mws_workspace
  ]
}