variable "cloudflare_api_token" {}
variable "cloudflare_origin_ca_key" {}
variable "cloudflare_zone_id" {}
variable "domain" {}
variable "email" {}
variable "keyfile" {}
variable "keyfile_pi" {}
variable "region" {}
variable "ssh_allow_list" {
  type = set(string)
  default = ["86.191.185.141"]
}
variable "subdomain" {}
