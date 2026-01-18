variable "resource_group" {
  type = object({
    name     = string
    location = string
  })
}

variable "vnet" {
  type = object({
    name = string
  })
}

variable "subnets" {
  type = map(object({
    name = string
  }))
}

variable "storage_account" {
  type = object({
    name = string
  })
}

variable "log_analytics" {
  type = object({
    name = string
    sku = string
  })
}

variable "vmss_frontend" {
  type = object({
    name           = string
    sku            = string
    instance_count = number
    subnet_key     = string
    admin_username = string
    admin_password = optional(string)
  })
}

variable "vmss_backend" {
  type = object({
    name           = string
    sku            = string
    instance_count = number
    subnet_key     = string
    admin_username = string
    admin_password = optional(string)
  })
}

variable "key_vault" {
  type = object({
    name = string
    sku  = string
  })
}

variable "key_vault_secret" {
  type = object({
    name  = string
    value = string
  })
}

variable "bastion" {
  type = object({
    name           = string
    public_ip_name = string
  })
}

variable "sql_server" {
  type = object({
    name           = string
    admin_username = string
    admin_password = string
  })
}

variable "sql_database" {
  type = object({
    name     = string
    sku_name = string
  })
}
