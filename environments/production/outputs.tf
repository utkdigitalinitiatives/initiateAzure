output "resource_group_name" {
  description = "Name of the production resource group"
  value       = azurerm_resource_group.production.name
}

output "vmss_id" {
  description = "ID of the VMSS"
  value       = module.vmss.vmss_id
}

output "vmss_name" {
  description = "Name of the VMSS"
  value       = module.vmss.vmss_name
}

output "vmss_identity_principal_id" {
  description = "Principal ID of the VMSS managed identity"
  value       = module.vmss.vmss_identity_principal_id
}

output "image_version" {
  description = "Image version deployed to VMSS"
  value       = var.image_version
}

output "image_id" {
  description = "Full image ID from gallery"
  value       = data.azurerm_shared_image_version.drupal.id
}
