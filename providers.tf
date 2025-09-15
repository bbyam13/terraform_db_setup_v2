# Authenticate using environment variables: https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-envvars.html
# export AWS_ACCESS_KEY_ID=KEY_ID
# export AWS_SECRET_ACCESS_KEY=SECRET_KEY
# export AWS_SESSION_TOKEN=SESSION_TOKEN

provider "aws" {
  shared_credentials_files = ["/Users/brendan.byam/.aws/credentials"]
  profile = "332745928618_databricks-sandbox-admin"
  region = var.region
}

# Authenticate using environment variables: https://registry.terraform.io/providers/databricks/databricks/latest/docs#argument-reference
# export DATABRICKS_CLIENT_ID=CLIENT_ID
# export DATABRICKS_CLIENT_SECRET=CLIENT_SECRET

provider "databricks" {
  alias      = "mws"
  host       = local.computed_databricks_provider_host
  account_id = var.databricks_account_id
  client_id = "7033afcf-c362-4b82-b4c8-33c4da9f1fd2"
  client_secret = "dose8e7af7277a797c088687bbb026dae287"
}