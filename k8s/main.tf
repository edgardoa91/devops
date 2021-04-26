# Set the variable value in *.tfvars file
# or using -var="do_token=..." CLI option
terraform {
  backend "http" {
  }
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.7.0"
    }
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "3.5.0"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
    token   = data.terraform_remote_state.secrets.outputs.do_token # This is the DO API token.
    # Alternatively, this can also be specified using environment variables ordered by precedence:
    #   DIGITALOCEAN_TOKEN,
    #   DIGITALOCEAN_ACCESS_TOKEN
}

###############################
# Start resource management & pool
#############################
data "digitalocean_kubernetes_versions" "versions" {}

resource "digitalocean_kubernetes_cluster" "cl01" {
  name    = "cl01"
  region  = "nyc3"
  version = data.digitalocean_kubernetes_versions.versions.latest_version

  node_pool {
    name       = "default-pool"
    size       = "s-1vcpu-2gb"
    node_count = 2
    tags       = ["dev", "nyc3"]
  }
}

resource "digitalocean_database_cluster" "postgres-db" {
  name       = "postgres-db-cluster"
  engine     = "pg"
  version    = "11"
  size       = "db-s-1vcpu-1gb"
  region     = "ams3"
  node_count = 1 #change to 2 for redundancy in production
}

resource "digitalocean_database_db" "minte-dev" {
  cluster_id = digitalocean_database_cluster.postgres-db.id
  name       = "minte_dev"
}

resource "digitalocean_database_firewall" "db-fw" {
  cluster_id = digitalocean_database_cluster.postgres-db.id

  rule {
    type  = "k8s"
    value = digitalocean_kubernetes_cluster.cl01.id
  }
}

########################
### GITLAB CONFIG #######
##########################
# variable "gitlab_access_token" {
#   type = string
# }

# Configure the DigitalOcean Provider
provider "gitlab" {
    token   = data.terraform_remote_state.secrets.outputs.git_token # This is the DO API token.
}

#####################################
# Add a group
resource "gitlab_group" "mintetv" {
    name = "mintetv"
    path = "mintetv"
    description = "MinteTV proyects group"
}

# Add a project to the group - example/example
data "gitlab_project" "minte" {
    id = 25538623
}

# Add a project to the group - example/example
resource "gitlab_project_cluster" "minte_kubernetes" {
    project = data.gitlab_project.minte.id
    name = "minte_cluster"
    domain = "dev.minte.tv"
    enabled = true
    kubernetes_api_url = digitalocean_kubernetes_cluster.cl01.endpoint
    kubernetes_token = digitalocean_kubernetes_cluster.cl01.kube_config[0].token
    kubernetes_ca_cert = base64decode(digitalocean_kubernetes_cluster.cl01.kube_config[0].cluster_ca_certificate)
    kubernetes_namespace = "minte"
    kubernetes_authorization_type = "rbac"
    environment_scope = "*"
    
}
