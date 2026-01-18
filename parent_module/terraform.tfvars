resource_group = {
  name     = "rg-devops-Sam-Demo"
  location = "Central India"
}

vnet = {
  name = "vnet1"
}

subnets = {
  app = {
    name = "subnet-app"
  }
  data = {
    name = "subnet-data"
  }
}

storage_account = {
  name = "devopsamdemounique"
}

log_analytics = {
  name = "law1"
  sku  = "PerGB2018"
}

# vmss_frontend = {
#   name           = "vmss-frontend"
#   sku            = "Standard_DS1_v2"
#   instance_count = 2
#   subnet_key     = "app"
#   admin_username = "azureuser"
#   admin_password = "Password@123!"
# }

# vmss_backend = {
#   name           = "vmss-backend"
#   sku            = "Standard_DS1_v2"
#   instance_count = 2
#   subnet_key     = "app"
#   admin_username = "azureuser"
#   admin_password = "Password@123!"
# }

vmss_frontend = {
  name           = "vmss-frontend"
  sku            = "Standard_DS1_v2"
  instance_count = 2
  subnet_key     = "app"
  admin_username = "azureuser"
}

vmss_backend = {
  name           = "vmss-backend"
  sku            = "Standard_DS1_v2"
  instance_count = 2
  subnet_key     = "app"
  admin_username = "azureuser"
}


key_vault = {
  name = "kv-devops-demo-sam"
  sku  = "standard"
}

key_vault_secret = {
  name  = "vm-admin-password"
  value = "Password@123!"
}

bastion = {
  name           = "bastion-devops"
  public_ip_name = "pip-bastion-devops"
}

sql_server = {
  name           = "sql-devops-server"
  admin_username = "sqladmin"
  admin_password = "Password@123!"
}

sql_database = {
  name     = "sqldb-devops"
  sku_name = "Basic"
}
