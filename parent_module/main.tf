module "infra" {
  source = "../child_module"

  resource_group = var.resource_group
  vnet            = var.vnet
  subnets         = var.subnets
  storage_account = var.storage_account
  log_analytics   = var.log_analytics

  vmss_frontend = var.vmss_frontend
  vmss_backend  = var.vmss_backend

  key_vault         = var.key_vault
  key_vault_secret  = var.key_vault_secret
  bastion           = var.bastion
  sql_server        = var.sql_server
  sql_database      = var.sql_database
}

