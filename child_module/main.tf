resource "azurerm_resource_group" "rg" {
  name     = var.resource_group.name
  location = var.resource_group.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  for_each = var.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.${index(keys(var.subnets), each.key)}.0/24"]
}



resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account.name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = var.log_analytics.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.log_analytics.sku
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = var.key_vault.sku

  soft_delete_retention_days = 7
  purge_protection_enabled  = false
  # enable_rbac_authorization = true <-- when enabling this line comment lines 54 to 64
}

resource "azurerm_key_vault_access_policy" "policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "Set",
    "List"
  ]
}

resource "azurerm_key_vault_secret" "secret" {
  name         = var.key_vault_secret.name
  value        = var.key_vault_secret.value
  key_vault_id = azurerm_key_vault.kv.id
   depends_on = [azurerm_key_vault_access_policy.policy]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.255.0/27"]
}

resource "azurerm_public_ip" "bastion" {
  name                = var.bastion.public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = var.bastion.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
    sku = "Standard"

  #  identity {
  #   type = "SystemAssigned"
  # }

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# resource "azurerm_role_assignment" "bastion_kv_access" {
#   scope                = azurerm_key_vault.kv.id
#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = azurerm_bastion_host.bastion.identity.principal_id
# }

resource "azurerm_mssql_server" "sql" {
  name                         = var.sql_server.name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location

  # administrator_login          = var.sql_server.admin_username
  # administrator_login_password = var.sql_server.admin_password
  administrator_login          = var.sql_server.admin_username
  administrator_login_password = data.azurerm_key_vault_secret.admin_password.value

  version = "12.0"
}

resource "azurerm_mssql_database" "db" {
  name      = var.sql_database.name
  server_id = azurerm_mssql_server.sql.id
  sku_name  = var.sql_database.sku_name
}

resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}
resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.10.0/24"]
}

resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-devops"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ipconfig"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name = "frontend-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "frontend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }
}


resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
  name                = var.vmss_frontend.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.vmss_frontend.sku
  instances           = var.vmss_frontend.instance_count

  # admin_username = var.vmss_frontend.admin_username
  # admin_password = var.vmss_frontend.admin_password
  admin_username = var.vmss_frontend.admin_username
  admin_password = data.azurerm_key_vault_secret.admin_password.value

  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "frontend-nic"
    primary = true

    ip_configuration {
      name      = "frontend-ipconfig"
      primary   = true
      subnet_id = azurerm_subnet.subnet["app"].id


    }
  }
}

resource "azurerm_lb" "internal" {
  name                = "ilb-backend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name      = "internal-ip"
    subnet_id = azurerm_subnet.subnet["app"].id
  }
}

resource "azurerm_lb_backend_address_pool" "backend" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "backend-pool"
}

resource "azurerm_lb_probe" "probe" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "http-probe"
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "rule" {
  loadbalancer_id                = azurerm_lb.internal.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal-ip"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.backend.id]
  probe_id                       = azurerm_lb_probe.probe.id
}

resource "azurerm_linux_virtual_machine_scale_set" "backend" {
  name                = var.vmss_backend.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.vmss_backend.sku
  instances           = var.vmss_backend.instance_count

  # admin_username = var.vmss_backend.admin_username
  # admin_password = var.vmss_backend.admin_password
  admin_username = var.vmss_backend.admin_username
  admin_password = data.azurerm_key_vault_secret.admin_password.value

  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "backend-nic"
    primary = true

    ip_configuration {
      name      = "backend-ipconfig"
      primary   = true
      subnet_id = azurerm_subnet.subnet["app"].id

      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.backend.id
      ]
    }
  }
}


# resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
#   name                = var.vmss_frontend.name
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   sku                 = var.vmss_frontend.sku
#   instances           = var.vmss_frontend.instance_count

#   admin_username = var.vmss_frontend.admin_username
#   admin_password = var.vmss_frontend.admin_password
#   disable_password_authentication = false

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts"
#     version   = "latest"
#   }

#   os_disk {
#     storage_account_type = "Standard_LRS"
#     caching              = "ReadWrite"
#   }

#   network_interface {
#     name    = "nic-frontend"
#     primary = true

#     ip_configuration {
#       name      = "ipconfig-frontend"
#       primary   = true
#       subnet_id = azurerm_subnet.subnet[var.vmss_frontend.subnet_key].id
#     }
#   }
# }

# resource "azurerm_linux_virtual_machine_scale_set" "backend" {
#   name                = var.vmss_backend.name
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   sku                 = var.vmss_backend.sku
#   instances           = var.vmss_backend.instance_count

#   admin_username = var.vmss_backend.admin_username
#   admin_password = var.vmss_backend.admin_password
#   disable_password_authentication = false

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts"
#     version   = "latest"
#   }

#   os_disk {
#     storage_account_type = "Standard_LRS"
#     caching              = "ReadWrite"
#   }

#   network_interface {
#     name    = "nic-backend"
#     primary = true

#     ip_configuration {
#       name      = "ipconfig-backend"
#       primary   = true
#       subnet_id = azurerm_subnet.subnet[var.vmss_backend.subnet_key].id
#     }
#   }
# }
data "azurerm_key_vault_secret" "admin_password" {
  name         = var.key_vault_secret.name
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.policy
  ]
}
