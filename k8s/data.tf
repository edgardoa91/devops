# Add a project to the group - example/example
data "terraform_remote_state" "secrets" {
    backend = "http"

    config = {
      do_token   = var.DIGITALOCEAN_KEY
      git_token   = var.GITLAB_TOKEN
    }
}
