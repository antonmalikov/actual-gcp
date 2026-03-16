variable "actual_tld" {
  type        = string
  description = "Top level domain of actual server to use for certificate generation"
}

variable "actual_subdomain" {
  type        = string
  description = "Subdomain of actual server to use for certificate generation"
}

variable "cloudflare_token" {
  type        = string
  description = "Cloudflare API token with permissions to manage DNS records for the domain used for certificate generation"
}

variable "container_host_network_tags" {
  type        = list(string)
  description = "List of network tags to add for firewall rules"
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_gcp_ed25519.pub"
}

variable "public_key" {
  type        = string
  description = "SSH public key to use if public key file doesn't exist (if running in HCP Terraform)"
  default     = ""
}

variable "user" {
  type = string
}

variable "vm_image_family" {
  type        = string
  description = "Family of image to use with VM creation"
}

variable "vm_image_project" {
  type        = string
  description = "Project to which the image belongs."
}

variable "vm_size" {
  type        = string
  description = "VM instance type."
}

variable "openid_discovery_url" {
  type = string
  description = "URL for OpenID Connect discovery document to use for workload identity federation"
}

variable "openid_clientid" {
  type = string
  description = "Client ID to use for workload identity federation"
}

variable "openid_secret" {
  type = string
  description = "Client secret to use for workload identity federation"
}