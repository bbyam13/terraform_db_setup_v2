# Databricks AWS Terraform Workspace Setup

This Terraform project automates the deployment of a Databricks environment on AWS including account-level configuration, telemetry data access from an existing S3 bucket, and workspace deployment with Unity Catalog integration.

## Project Structure

The project is organized as a unified Terraform deployment that creates account-level resources (Unity Catalog metastore and account groups), telemetry data infrastructure, and workspace deployment in a single coordinated process. The deployment creates foundational resources that are shared across workspaces - the Unity Catalog metastore and account groups, infrastructure for accessing telemetry data from an existing S3 bucket with a Unity Catalog external location, and workspaces with customer managed VPC along with associated UC catalogs with multiple schemas and permissions for the account groups. It is designed to handle deploying several workspaces within the same account using the same Unity Catalog metastore.

## Setup

### Prerequisites
- **Terraform** installed
- **AWS CLI** 
- **Databricks CLI** 
- **Databricks Service Principal** created in Databricks account for automation with Account Admin access

### 2. Authentication with AWS and Databricks

#### AWS Authentication
Configure AWS credentials using one of these methods:

```bash
# Option 1: AWS CLI configure
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region, and output format

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-2"

# Option 3: AWS Profile (if using multiple accounts)
export AWS_PROFILE="your-profile-name"

# Verify AWS authentication
aws sts get-caller-identity
```

#### Databricks Authentication
Set up Databricks authentication using environment variables:

```bash
export DATABRICKS_CLIENT_ID="your-service-principal-client-id"
export DATABRICKS_CLIENT_SECRET="your-service-principal-client-secret"
```



### 3. Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# =============================================================================
# AWS Configuration
# =============================================================================
aws_account_id = "123456789012"           # Your AWS account ID
region = "us-east-2"                      # Your preferred AWS region

# =============================================================================
# Databricks Configuration  
# =============================================================================
admin_user = "your-email@company.com"     # Your admin email
metastore_name = "your-metastore-name"    # Unity Catalog metastore name
executor_application_id = "abc123..."     # Service principal app ID
databricks_account_id = "xyz789..."       # Your Databricks account ID

# =============================================================================
# Telemetry Configuration (Optional)
# =============================================================================
telemetry_bucket_name = "your-telemetry-bucket"    # Set to null to disable
telemetry_location_name = "telemetry-location"     # External location name
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 5.  Add and Destroy Workspaces

#### Add a new workspace
  1. Add a new workspace provider in `providers.tf`

  ```hcl
    provider "databricks" {
      alias      = "STAGE_workspace"
      host       = module.STAGE_workspace.databricks_host #this must match the module name
      account_id = var.databricks_account_id
    }
  ```

  2. Copy a sample workspace file - `workspace_dev.tf`
  3. Modify the file for specs of the new workspace

  ```hcl
    module "STAGE_workspace" { #update to unique name
        
        ......
          
          databricks.created_workspace = databricks.STAGE_workspace 
        
        .......

        #variables per workspace
        resource_prefix                 = "byam-STAGE" #name of the workspace
        deployment_name                 = "byam-STAGE" #url of workspace 
        telemetry_bucket_env_prefix     = "STAGE"  # bucket prefix
        
        #Whether the catalog is accessible from all workspaces or a specific set of workspaces
        catalog_isolation_mode          = "OPEN"
      
      .......

      #workspace specific outputs
      output "STAGE_workspace_url" { #update this to match the module name
        value       = module.STAGE_workspace.databricks_host #update this to match the module nam

      .......

      output "STAGE_workspace_service_principal_id" { #update this to match the module name
        value       = module.STAGE_workspace.service_principal_application_id #update this to match the module name
  ```
  
  4. Deploy 
  ```bash
# Review the deployment plan
terraform plan

# Deploy the new workspace resources
terraform apply
```
#### Destroy a workspace

1. Target Destory the specific workspace module to delete
```bash

# Review the deployment plan
terraform plan -destroy -target=module.prod_workspace

# Deploy the new workspace resources
tterraform plan -destroy -target=module.prod_workspace
```

**PLEASE NOTE**: The resources for accessing the telemetry bucket are dependent on an existing workspace. Currently, `telemetry_location.tf` is setup to depend on `workspace_dev` to handle this. Therefore, attempting to delete the module `workspace_dev` would trigger a delete of the telemery bucket access. (This is blocked by lifecycle rules)


**WARNING: The command `terrafrom destroy` WILL ATTEMPT TO DELETE ALL RESOURCES**





## Archictecture

### 1. Account Level Configuration

The account-level configuration creates foundational resources that will be used across workspaces - the Unity Catalog metastore and account groups

#### `account_groups.tf`
- **Purpose**: Creates account-level user groups with automated member assignments
- **Contents**:
  - **Locals Configuration**: Defines all group configurations using a `locals` block for maintainability
  - **Dynamic Group Creation**: Uses `for_each` to create groups based on the local configuration
  - **Group Types Created**:
    - **Data Engineers Group**: Full workspace access with cluster creation privileges
    - **Data Analysts Group**: Workspace and SQL access for analysis tasks
    - **Data Scientists Group**: Workspace and SQL access for ML/analytics work
    - **Product Managers Group**: Workspace and SQL access for business insights
    - **Design Group**: Workspace and SQL access for design-related analytics
    - **Backend Group**: Workspace access for backend development teams
    - **Metastore Admin Group**: Ownership and control over metastore
  - **Admin User Assignment**: Automatically assigns the specified admin user to metastore admins group
  - **Service Principal Assignment**: Automatically assigns the executor service principal to metastore admins group

#### `account_metastore.tf`
- **Purpose**: Creates the Unity Catalog metastore
- **Contents**:
  - Unity Catalog metastore resource configuration
  - Ownership assignment to specified user

#### `telemetry_location.tf`
- **Purpose**: Creates external location and IAM infrastructure for telemetry data access. Each workspace will have a volume in the schema 'raw' that accesses a subfolder of the telemetry s3 bucket. Only created if bucket name provided in terraform.tfvars
- **Contents**:
  - **IAM Role and Policy**: Secure role for Databricks to access telemetry S3 bucket
  - **Storage Credential**: Databricks credential linked to IAM role for S3 access
  - **External Location**: Unity Catalog external location pointing to telemetry S3 bucket
  - **File Events**: Enables automatic file event notifications with managed SQS queue
  - **S3 Bucket Integration**: References existing telemetry data bucket for external access
  - **Conditional Creation**: Only creates resources when telemetry bucket variable is set


### 3. Workspace Deployment (`modules/workspace_setup/`)

Deploys a Databricks workspace using a modular architecture based on the [Security Reference Architecture (SRA) Template](https://github.com/databricks/terraform-databricks-sra/tree/main/aws). The deployment creates a complete Databricks workspace with customer managed VPC, Unity Catalog catalog for the workspace, a service principal, and a volume to access telemetry data.

The workspace module orchestrates both account and workspace API resources through organized sub-modules.

#### Databricks Account API Modules (`modules/databricks_account/`)

##### `unity_catalog_metastore_assignment/`
- **Purpose**: Assigns Unity Catalog metastore to the workspace
- **Contents**: Links metastore to workspace for Unity Catalog functionality

##### `user_assignment/`
- **Purpose**: Assigns admin user permissions to the workspace
- **Contents**: Grants workspace ADMIN permissions to specified user account

##### `workspace/`
- **Purpose**: Core workspace infrastructure deployment
- **Contents**:
  - **Cross-Account IAM Role**: Secure credential configuration with time delays
  - **Storage Configuration**: Root bucket setup for DBFS storage
  - **Network Configuration**: VPC, subnet, and security group integration
  - **Private Access Settings**: Account-level private access configuration
  - **Workspace Creation**: Complete Databricks workspace with enterprise pricing tier and secure cluster connectivity

#### Databricks Workspace API Modules (`modules/databricks_workspace/`)

##### `restrictive_root_bucket/`
- **Purpose**: Applies security-hardened bucket policies to root storage
- **Contents**:
  - **Restrictive Access Controls**: Limits Databricks access to specific paths and operations
  - **SSL Enforcement**: Denies non-SSL requests to enhance security

##### `system_schema/`
- **Purpose**: Enables Databricks system tables for observability and governance
- **Contents**: Creates system schemas for access, compute, lakeflow, marketplace, storage, serving, and query monitoring

##### `unity_catalog_catalog_creation/`
- **Purpose**: Creates Unity Catalog structure with security controls
- **Contents**:
  - **KMS Encryption**: Dedicated encryption key for catalog storage
  - **S3 Bucket**: Secure data lake bucket with encryption and versioning
  - **IAM Role**: Unity Catalog access role with least-privilege permissions
  - **Storage Credential**: Databricks credential for S3 access
  - **External Location**: Unity Catalog external location for data access
  - **Catalog and Schema Structure**: Organized data layer schemas

#### Core Configuration Files

#### `main.tf`
- **Purpose**: Orchestrates all modules and defines resource dependencies
- **Contents**: Module calls for workspace creation, metastore assignment, user permissions, catalog setup, system tables, and restrictive bucket policies

#### `network.tf`
- **Purpose**: Creates customer managed VPC infrastructure
- **Contents**: VPC, subnets, internet gateway, NAT gateway, and routing configuration

#### `vpc_endpoints.tf`
- **Purpose**: Establishes secure AWS service connectivity
- **Contents**: VPC endpoints for S3, Kinesis, and STS services

#### `credential.tf`
- **Purpose**: Creates cross-account IAM role for Databricks
- **Contents**: IAM role, policies, and trust relationships for secure AWS resource access

#### `root_s3_bucket.tf`
- **Purpose**: Creates root storage bucket for workspace
- **Contents**: S3 bucket with encryption, versioning, and security configurations

#### `service_principal.tf`
- **Purpose**: Creates workspace service principal for automated operations
- **Contents**: Job executor service principal with workspace ADMIN permissions for automation tasks

#### `telemetry_volume.tf`
- **Purpose**: Creates Unity Catalog volumes for telemetry data access
- **Contents**: 
  - **External Telemetry Volume**: Maps to environment-specific telemetry data in S3
  - **Managed Metadata Volume**: Stores checkpoint data and processing metadata
  - **Conditional Creation**: Only creates volumes if telemetry external location exists