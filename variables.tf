# Required variables
variable "cloudstack_api_url" {
    default = "https://10.246.164.6:9443/client/api"
}
variable "cloudstack_api_key" {}
variable "cloudstack_secret_key" {}
variable "cloudstack_project" {}

variable "cloudstack_zone" {
    default = "TOR-20P"
}

variable "vm_username" {
    default = "cloudops"
}

# default instance counts
variable "elastic_count" {
    default = 1
}
variable "kibana_count" {
    default = 1
}
variable "mysql_count" {
    default = 1
}
variable "k8s_control_count" {
    default = 1
}
variable "k8s_nodes_count" {
    default = 2
}
