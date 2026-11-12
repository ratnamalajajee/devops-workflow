terraform {
  backend "azurerm" {
    resource_group_name  = "rg-nextgen-dev"
    storage_account_name = "stnextgendev7k2q"
    container_name       = "tfstate"
    key                  = "platform.tfstate"
    use_azuread_auth     = true   # Entra ID, no account key
  }
}
