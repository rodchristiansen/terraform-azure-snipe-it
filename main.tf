# Set your URL here
locals {
  app_name = "assets-inventory-company"
  app_url  = "https://assets.inventory.company.com"
}

# Data Source to fetch the current client config
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "assets" {
  name     = "Inventory"
  location = "Canada Central"
  tags = {
    GitOps = "Terraformed"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "assets_vnet" {
  name                = "assets-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.assets.location
  resource_group_name = azurerm_resource_group.assets.name
}

# Subnet for general assets
resource "azurerm_subnet" "assets_subnet" {
  name                 = "assets-subnet"
  resource_group_name  = azurerm_resource_group.assets.name
  virtual_network_name = azurerm_virtual_network.assets_vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "webappDelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for MySQL flexible server
resource "azurerm_subnet" "mysql_flexible_server_subnet" {
  name                 = "mysql-flexible-server-subnet"
  resource_group_name  = azurerm_resource_group.assets.name
  virtual_network_name = azurerm_virtual_network.assets_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  delegation {
    name = "mysqlDelegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Key Vault
resource "azurerm_key_vault" "assets_inventory_credentials" {
  name                        = "assets-inventory-creds"
  location                    = azurerm_resource_group.assets.location
  resource_group_name         = azurerm_resource_group.assets.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
}

# Key Vault Secrets
data "azurerm_key_vault_secret" "db_admin_password" {
  name         = "db-admin-password"
  key_vault_id = azurerm_key_vault.assets_inventory_credentials.id
}

data "azurerm_key_vault_secret" "app_key" {
  name         = "AppKey"
  key_vault_id = azurerm_key_vault.assets_inventory_credentials.id
}

data "azurerm_key_vault_secret" "sendgrid_api_key" {
  name         = "SendGridApiKey"
  key_vault_id = azurerm_key_vault.assets_inventory_credentials.id
}

# MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "assets_inventory_db" {
  name                   = "assets-inventory-flexible-server"
  resource_group_name    = azurerm_resource_group.assets.name
  location               = azurerm_resource_group.assets.location
  administrator_login    = "assetsadmin"
  administrator_password = data.azurerm_key_vault_secret.db_admin_password.value
  tags                   = {}
  zone                   = "1"
  sku_name               = "B_Standard_B1ms"
  
  storage {
    iops    = 360
    size_gb = 20
  }
  
  version = "8.0.21"
  
  delegated_subnet_id = azurerm_subnet.mysql_flexible_server_subnet.id
}

# MySQL Flexible Database
resource "azurerm_mysql_flexible_database" "snipeit_db" {
  name                = "snipeit"
  resource_group_name = azurerm_mysql_flexible_server.assets_inventory_db.resource_group_name
  server_name         = azurerm_mysql_flexible_server.assets_inventory_db.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
  depends_on          = [azurerm_mysql_flexible_server.assets_inventory_db]
}

# Storage Account
resource "azurerm_storage_account" "snipeit_storage_account" {
  name                     = "assetsinventoryecuad"
  resource_group_name      = azurerm_resource_group.assets.name
  location                 = azurerm_resource_group.assets.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

# Storage Share for Snipe IT
resource "azurerm_storage_share" "snipeit" {
  name                 = "snipeit"
  storage_account_name = azurerm_storage_account.snipeit_storage_account.name
  quota                = 50
}

# Storage Share Logs for Snipe IT
resource "azurerm_storage_share" "snipeit_logs" {
  name                 = "snipeit-logs"
  storage_account_name = azurerm_storage_account.snipeit_storage_account.name
  quota                = 50
}


# DigiCertGlobalRootCA.crt.pem DB certificate to File Share
variable "certificate_base64" {
  default = <<-EOT
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURyekNDQXBlZ0F3SUJBZ0lRQ0R2Z1ZwQkNSckdoZFdySldaSEhTakFOQmdrcWhraUc5dzBCQVFVRkFEQmgKTVFzd0NRWURWUVFHRXdKVlV6RVZNQk1HQTFVRUNoTU1SR2xuYVVObGNuUWdTVzVqTVJrd0Z3WURWUVFMRXhCMwpkM2N1WkdsbmFXTmxjblF1WTI5dE1TQXdIZ1lEVlFRREV4ZEVhV2RwUTJWeWRDQkhiRzlpWVd3Z1VtOXZkQ0JEClFUQWVGdzB3TmpFeE1UQXdNREF3TURCYUZ3MHpNVEV4TVRBd01EQXdNREJhTUdFeEN6QUpCZ05WQkFZVEFsVlQKTVJVd0V3WURWUVFLRXd4RWFXZHBRMlZ5ZENCSmJtTXhHVEFYQmdOVkJBc1RFSGQzZHk1a2FXZHBZMlZ5ZEM1agpiMjB4SURBZUJnTlZCQU1URjBScFoybERaWEowSUVkc2IySmhiQ0JTYjI5MElFTkJNSUlCSWpBTkJna3Foa2lHCjl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUE0anZoRVhMZXFLVFRvMWVxVUtLUEMzZVF5YUtsN2hMT2xsc0IKQ1NETUFaT25UakMzVS9kRHhHa0FWNTNpalNMZGh3WkFBSUVKenM0Ymc3L2Z6VHR4UnVMV1pzY0ZzM1luRm85NwpuaDZWZmU2M1NLTUkydGF2ZWd3NUJtVi9TbDBmdkJmNHE3N3VLTmQwZjNwNG1WbUZhRzVjSXpKTHYwN0E2RnB0CjQzQy9keEMvL0FIMmhkbW9SQkJZTXFsMUdOWFJvcjVINGlkcTlKb3orRWtJWUl2VVg3UTZoTCtocWtwTWZUN1AKVDE5c2RsNmdTemVSbnR3aTVtM09GQnFPYXN2K3piTVVaQmZIV3ltZU1yL3k3dnJUQzBMVXE3ZEJNdG9NMU8vNApnZFc3alZnL3RSdm9TU2lpY05veEJOMzNzaGJ5VEFwT0I2anRTajFldFgramtNT3ZKd0lEQVFBQm8yTXdZVEFPCkJnTlZIUThCQWY4RUJBTUNBWVl3RHdZRFZSMFRBUUgvQkFVd0F3RUIvekFkQmdOVkhRNEVGZ1FVQTk1UU5WYlIKVEx0bThLUGlHeHZEbDdJOTBWVXdId1lEVlIwakJCZ3dGb0FVQTk1UU5WYlJUTHRtOEtQaUd4dkRsN0k5MFZVdwpEUVlKS29aSWh2Y05BUUVGQlFBRGdnRUJBTXVjTjZwSUV4SUsrdDFFbkU5U3NQVGZyZ1QxZVhrSW95UVkvRXNyCmhNQXR1ZFhIL3ZUQkgxakx1RzJjZW5Ubm1DbXJFYlhqY0tDaHpVeUltWk9Na1hEaXF3OGN2cE9wLzJQVjVBZGcKMDZPL25Wc0o4ZFdPNDFQMGptUDZQNmZidEdiZlltYlcwVzVCamZJdHRlcDNTcCtkV09JcldjQkFJKzB0S0lKRgpQbmxVa2lhWTRJQklxRGZ2OE5aNVlCYmVyT2dPelc2c1JCYzRMMG5hNFVVK0tyazJVODg2VUFiM0x1akVWMGxzCllTRVkxUVN0ZUR3c09vQnJwK3V2RlJUcDJJbkJ1VGhzNHBGc2l2OWt1WGNsVnpEQUd5U2o0ZHpwMzBkOHRiUWsKQ0FVdzdDMjlDNzlGdjFDNXFmUHJtQUVTcmNpSXhwZzBYNDBLUE1icDFaV1ZiZDQ9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
EOT
}

resource "null_resource" "write_cert" {
  triggers = {
    cert_base64 = var.certificate_base64
  }

  provisioner "local-exec" {
    command = "echo '${var.certificate_base64}' | base64 --decode > ${path.module}/DigiCertGlobalRootCA.crt.pem"
  }
}

resource "azurerm_storage_share_file" "cert_file" {
  name             = "DigiCertGlobalRootCA.crt.pem"
  storage_share_id = azurerm_storage_share.snipeit.id
  source           = "${path.module}/DigiCertGlobalRootCA.crt.pem"

  depends_on = [null_resource.write_cert]
}


# MySQL Flexible Server Configuration for innodb_buffer_pool_load_at_startup
resource "azurerm_mysql_flexible_server_configuration" "innodb_load_at_startup" {
  name                = "innodb_buffer_pool_load_at_startup"
  server_name         = azurerm_mysql_flexible_server.assets_inventory_db.name
  resource_group_name = azurerm_mysql_flexible_server.assets_inventory_db.resource_group_name
  value               = "OFF"
}

# MySQL Flexible Server Configuration for innodb_buffer_pool_dump_at_shutdown
resource "azurerm_mysql_flexible_server_configuration" "innodb_dump_at_shutdown" {
  name                = "innodb_buffer_pool_dump_at_shutdown"
  server_name         = azurerm_mysql_flexible_server.assets_inventory_db.name
  resource_group_name = azurerm_mysql_flexible_server.assets_inventory_db.resource_group_name
  value               = "OFF"
}

# MySQL Flexible Server Configuration for sql_generate_invisible_primary_key
resource "azurerm_mysql_flexible_server_configuration" "sql_invisible_primary_key" {
  name                = "sql_generate_invisible_primary_key"
  server_name         = azurerm_mysql_flexible_server.assets_inventory_db.name
  resource_group_name = azurerm_mysql_flexible_server.assets_inventory_db.resource_group_name
  value               = "OFF"
}

# Service Plan for Azure App Service
resource "azurerm_service_plan" "assets_inventory_plan" {
  name                = "assets-inventory-service-plan"
  location            = azurerm_resource_group.assets.location
  resource_group_name = azurerm_resource_group.assets.name
  os_type             = "Linux"
  sku_name            = "B2"
}

# Resources for Azure App Service
resource "azurerm_linux_web_app" "assets_inventory_app" {
  name                      = local.app_name
  resource_group_name       = azurerm_resource_group.assets.name
  location                  = azurerm_resource_group.assets.location
  service_plan_id           = azurerm_service_plan.assets_inventory_plan.id
  virtual_network_subnet_id = azurerm_subnet.assets_subnet.id

  site_config {
    ftps_state                = "Disabled"
    http2_enabled             = "true"

	application_stack {
	  docker_image_name   = "index.docker.io/snipe/snipe-it:latest"
	  }
  }

  storage_account {
    name         = "snipeit"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.snipeit_storage_account.name
    share_name   = azurerm_storage_share.snipeit.name
    access_key   = azurerm_storage_account.snipeit_storage_account.primary_access_key
    mount_path   = "/var/lib/snipeit"
  }

  storage_account {
    name         = "snipeit-logs"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.snipeit_storage_account.name
    share_name   = azurerm_storage_share.snipeit_logs.name
    access_key   = azurerm_storage_account.snipeit_storage_account.primary_access_key
    mount_path   = "/var/www/html/storage/logs"
  }

  app_settings = {
    "APP_KEY"                             = data.azurerm_key_vault_secret.app_key.value
    "APP_URL"                             = local.app_url
    "APP_TIMEZONE"                        = "America/Vancouver"
    "APP_ENV"                             = "production"
    "APP_DEBUG"                           = false
    "APP_LOCALE"                          = "en-US"
    "MYSQL_DATABASE"                      = "snipeit"
    "MYSQL_USER"                          = azurerm_mysql_flexible_server.assets_inventory_db.administrator_login
    "MYSQL_PASSWORD"                      = data.azurerm_key_vault_secret.db_admin_password.value
    "DB_CONNECTION"                       = "mysql"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = true
    "MYSQL_PORT_3306_TCP_ADDR"            = azurerm_mysql_flexible_server.assets_inventory_db.fqdn
    "MYSQL_PORT_3306_TCP_PORT"            = "3306"
    "DB_SSL_IS_PAAS"                      = true
    "DB_SSL"                              = true
    "DB_SSL_CA_PATH"                      = "/var/lib/snipeit/DigiCertGlobalRootCA.crt.pem"
    "MAIL_DRIVER"                         = "smtp"
    "MAIL_ENV_ENCRYPTION"                 = "tcp"
    "MAIL_PORT_587_TCP_ADDR"              = "smtp.sendgrid.net"
    "MAIL_PORT_587_TCP_PORT"              = "587"
    "MAIL_ENV_USERNAME"                   = "apikey"
    "MAIL_ENV_PASSWORD"                   = data.azurerm_key_vault_secret.sendgrid_api_key.value
    "MAIL_ENV_FROM_ADDR"                  = "assetsadmins@company.com"
    "MAIL_ENV_FROM_NAME"                  = "Assets Admins"
    "SCIM_STANDARDS_COMPLIANCE"           = true
    "SCIM_TRACE"                          = false
  }

  https_only = true
}


# Allow MySQL traffic to the virtual network
resource "azurerm_network_security_rule" "allow_mysql_from_vnet" {
  name                        = "assets-allow-mysql-from-vnet"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_network_security_group.assets_vnet_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.assets_vnet_nsg.name
}

# Control inbound and outbound network traffic to resources in the vnet
resource "azurerm_network_security_group" "assets_vnet_nsg" {
  name                = "assets-vnet-nsg"
  location            = azurerm_resource_group.assets.location
  resource_group_name = azurerm_resource_group.assets.name

  security_rule {
    name                       = "allow-https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-mysql"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*" // Any source port
    destination_port_range     = "3306" // The MySQL port
    source_address_prefix      = "10.0.2.0/24" // The subnet of your App Service
    destination_address_prefix = "10.0.3.0/24" // The subnet of your MySQL server
  }
}

# Associates the defined Network Security Group (NSG) with a specific subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.assets_subnet.id
  network_security_group_id = azurerm_network_security_group.assets_vnet_nsg.id
}

# Integrates an Azure App Service with a subnet within a virtual network
resource "azurerm_app_service_virtual_network_swift_connection" "assets_connection" {
  app_service_id = azurerm_linux_web_app.assets_inventory_app.id
  subnet_id      = azurerm_subnet.assets_subnet.id
}
