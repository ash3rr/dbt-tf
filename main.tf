// define the variables we will use
variable "dbt_account_id" {
  type = number
}

variable "dbt_token" {
  type = string
}

variable "dbt_host_url" {
  type = string
}



// initialize the provider and set the settings
terraform {
  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "0.2.6"
    }
  }
}

provider "dbtcloud" {
  account_id = var.dbt_account_id
  token      = var.dbt_token
  host_url   = var.dbt_host_url
}


// create a project
resource "dbtcloud_project" "my_project" {
  name = "dbtautomation-tf"
}


// create a connection and link the project to the connection
// this is an example with Snowflake but for other warehouses please look at the resource docs
resource "dbtcloud_connection" "my_connection" {
  project_id = dbtcloud_project.my_project.id
  type       = "snowflake"
  name       = "Snowflake warehouse"
  account    = "bigdatasolutions.west-europe.azure"
  database   = "fasttrack_dev"
  role       = "transformer_ft_dev"
  warehouse  = "transformer_ft_dev_wh"
  allow_keep_alive  = true
}

resource "dbtcloud_project_connection" "my_project_connection" {
  project_id    = dbtcloud_project.my_project.id
  connection_id = dbtcloud_connection.my_connection.connection_id
}


// link a repository to the dbt Cloud project
// this example adds a github repo for which we know the installation_id but the resource docs have other examples
resource "dbtcloud_repository" "my_repository" {
  project_id             = dbtcloud_project.my_project.id
  remote_url             = "git@ssh.dev.azure.com:v3/kaitofi/Kaito%20Fast%20Track/DBT"
  #github_installation_id = 9876
  git_clone_strategy     = "deploy_key"
}

resource "dbtcloud_project_repository" "my_project_repository" {
  project_id    = dbtcloud_project.my_project.id
  repository_id = dbtcloud_repository.my_repository.repository_id
}


// create 2 environments, one for Dev and one for Prod
// for Prod, we need to create a credential as well
resource "dbtcloud_environment" "my_dev" {
  dbt_version   = "1.5.0-latest"
  name          = "Dev"
  project_id    = dbtcloud_project.my_project.id
  type          = "development"
}

resource "dbtcloud_environment" "my_prod" {
  dbt_version   = "1.5.0-latest"
  name          = "Prod"
  project_id    = dbtcloud_project.my_project.id
  type          = "deployment"
  credential_id = dbtcloud_snowflake_credential.prod_credential.credential_id
}

// we use user/password but there are other options on the resource docs
resource "dbtcloud_snowflake_credential" "prod_credential" {
  project_id  = dbtcloud_project.my_project.id
  auth_type   = "password"
  num_threads = 16
  schema      = "analytics"
  user        = "my_snowflake_user"
  // note, this is a simple example to get Terraform and dbt Cloud working, but do not store passwords in the config for a real productive use case
  // there are different strategies available to protect sensitive input: https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables
  password    = "my_snowflake_password"
}