terraform {
  required_version = ">= 1.9, < 2.0"
  backend "azurerm" { use_azuread_auth = true }
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
variable "subscription_id" { type = string }
variable "location" {
  type    = string
  default = "centralindia"
}
variable "app_name" { type = string }
resource "azurerm_resource_group" "app" {
  name     = "${var.app_name}-rg"
  location = var.location
}
resource "azurerm_service_plan" "app" {
  name                = "${var.app_name}-plan"
  resource_group_name = azurerm_resource_group.app.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"
  worker_count        = 1
}
resource "random_password" "session" {
  length  = 64
  special = false
}
resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  resource_group_name = azurerm_resource_group.app.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.app.id
  https_only          = true
  identity { type = "SystemAssigned" }
  site_config {
    always_on                         = true
    minimum_tls_version               = "1.2"
    ftps_state                        = "Disabled"
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 2
    app_command_line                  = "gunicorn --bind 0.0.0.0:8000 --workers 1 --threads 1 --timeout 60 app:app"
    application_stack { python_version = "3.12" }
  }
  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    DATABASE_PATH                  = "/home/data/volt-electronics.db"
    SECRET_KEY                     = random_password.session.result
    PRODUCTION                     = "1"
  }
  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
}
output "url" { value = "https://${azurerm_linux_web_app.app.default_hostname}" }
output "resource_group" { value = azurerm_resource_group.app.name }
