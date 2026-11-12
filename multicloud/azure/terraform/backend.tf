terraform {
  backend "azurerm" {
    resource_group_name  = "rg-shopnow-dev"
    storage_account_name = "stshopnowdev7k2q"
    container_name       = "tfstate"
    key                  = "platform.tfstate"
    use_azuread_auth     = true   # Entra ID, no account key
  }
}
