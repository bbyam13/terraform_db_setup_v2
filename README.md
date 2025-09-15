# Databricks AWS Terraform Workspace Setup

This Terraform project automates the deployment of a Databricks environment on AWS including account-level configuration, telemetry data access from an existing S3 bucket, and workspace deployment with Unity Catalog integration.

## Project Structure

The project is organized as a unified Terraform deployment that creates account-level resources (Unity Catalog metastore and account groups), telemetry data infrastructure, and workspace deployment in a single coordinated process. The deployment creates foundational resources that are shared across workspaces - the Unity Catalog metastore and account groups, infrastructure for accessing telemetry data from an existing S3 bucket with a Unity Catalog external location, and workspaces with customer managed VPC along with associated UC catalogs with multiple schemas and permissions for the account groups. It is designed to handle deploying several workspaces within the same account using the same Unity Catalog metastore.

### Setup 
1. Set variables in `terraform.tfvars`:
   - **aws_account_id**: aws account id for deployment
   - **region**: aws region for deployment
   - **admin_user**: Admin user email for workspaces and catalog management
   - **metastore_name**: Unity Catalog metastore name
   - **executor_application_id**: The service principal executing the terraform
   - **databricks_account_id**: databricks account id
   - **telemetry_bucket_name**: S3 Bucket where telemetry data resides
   - **telemetry_location_name**: name of Unity Catalog External location that connects to the telemetry bucket


### Deployment Process

1. **Configure Variables**
   - Set your account level configuration values in `terraform.tfvars`
   - For deployment without telemetry: set `telemetry_bucket_name = null`

2. **Multi-Workspace Deployment**
   - use the example file 'dev_workspace.tfvars' to deploy a workspace. Once you have added the module with the required configurations,  you can just apply the terraform again.
   ```bash
   terraform apply
   ```
   
3. **Workspace Destory**
   - To destory a worksapce, destory the specific workspace module
   ```bash
   terraform destroy -target=module.dev_workspace
   ```


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