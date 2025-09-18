output "databricks_host" {
  value = module.databricks_mws_workspace.workspace_url
}

output "metastore_assignment" {
  value = module.unity_catalog_metastore_assignment.metastore_assignment
}

output "service_principal_application_id" {
  value = databricks_service_principal.job_executor_sp.application_id
  description = "Service principal application ID"
}
