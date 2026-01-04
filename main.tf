data "azurerm_client_config" "current" {}


resource "azurerm_resource_group" "rg1" {
  name     = var.rgname
  location = var.location
}

resource "tls_private_key" "aks_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_role_assignment" "kv_secrets_officer_tf" {
  scope                = module.keyvault.keyvault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [
    module.keyvault
  ]
}



module "ServicePrincipal" {
  source                 = "./modules/ServicePrincipal"
  service_principal_name = var.service_principal_name

  depends_on = [
    azurerm_resource_group.rg1
  ]
}

resource "azurerm_role_assignment" "rolespn" {

  scope                = "/subscriptions/${var.SUB_ID}"
  role_definition_name = "Contributor"
  principal_id         = module.ServicePrincipal.service_principal_object_id

  depends_on = [
    module.ServicePrincipal
  ]
}
# Create Key Vault Module
module "keyvault" {
  source                      = "./modules/keyvault"
  keyvault_name               = var.keyvault_name
  location                    = var.location
  resource_group_name         = var.rgname
  service_principal_name      = var.service_principal_name
  service_principal_object_id = module.ServicePrincipal.service_principal_object_id
  service_principal_tenant_id = module.ServicePrincipal.service_principal_tenant_id

  depends_on = [
    module.ServicePrincipal
  ]
}

resource "azurerm_key_vault_secret" "example" {
  name         = module.ServicePrincipal.client_id
  value        = module.ServicePrincipal.client_secret
  key_vault_id = module.keyvault.keyvault_id

  depends_on = [
    azurerm_role_assignment.kv_secrets_officer_tf
  ]
}

resource "azurerm_key_vault_secret" "aks_ssh_private_key" {
  name         = "aks-ssh-private-key"
  value        = tls_private_key.aks_ssh.private_key_pem
  key_vault_id = module.keyvault.keyvault_id

  depends_on = [
    azurerm_role_assignment.kv_secrets_officer_tf
  ]
}

# Create Azure Kubernetes Service
module "aks" {
  source                 = "./modules/aks/"
  service_principal_name = var.service_principal_name
  client_id              = module.ServicePrincipal.client_id
  client_secret          = module.ServicePrincipal.client_secret
  location               = var.location
  resource_group_name    = var.rgname
  ssh_public_key         = tls_private_key.aks_ssh.public_key_openssh

  depends_on = [
    module.ServicePrincipal
  ]

}

resource "local_file" "kubeconfig" {
  depends_on   = [module.aks]
  filename     = "./kubeconfig"
  content      = module.aks.config
  
}