variable "project" {
  type    = string
  default = "km"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "subscription_id" {
  type = string
}

variable "address_space" {
  type    = string
  default = "192.168.254.0/23"
}

variable "application_gateway_min_capacity" {
  type    = number
  default = 0
}

variable "application_gateway_max_capacity" {
  type    = number
  default = 125
}

variable "dns_zone_id" {
  type = string
}

variable "backend_address_pool_ip_addresses" {
  type    = set(string)
  default = ["10.218.36.30"]
}

variable "tenants" {
  type    = set(string)
  default = ["contoso", "fabrikam"]
}
