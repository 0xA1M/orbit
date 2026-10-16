# ecr module inputs: the service set that gets a repo, and the Name tag prefix

# set, not list, keys the for_each by service name so order changes cause no churn
variable "service_list" {
  type        = set(string)
  description = "Services list to deploy"
}

# prepended to every repo Name tag, e.g. orbit-frontend-repo
variable "name_prefix" {
  type        = string
  description = "Prefix for every Name tag in this module"
}
