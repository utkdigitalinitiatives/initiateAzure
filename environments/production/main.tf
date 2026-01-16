terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.57"
    }
  }

  # Backend configuration for Terraform state
  # Uncomment and configure for your Azure Storage backend
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstateaccount"
  #   container_name       = "tfstate"
  #   key                  = "production/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

# Data source: Get image version from Azure Compute Gallery
data "azurerm_shared_image_version" "drupal" {
  name                = var.image_version
  image_name          = var.image_name
  gallery_name        = var.gallery_name
  resource_group_name = var.gallery_resource_group_name
}

# Resource group for production resources
resource "azurerm_resource_group" "production" {
  name     = "drupal-production-rg"
  location = var.location

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Single VMSS with rolling updates (replaces blue/green strategy)
module "vmss" {
  source = "../../modules/drupal-vmss"

  environment                   = "production"
  resource_group_name           = azurerm_resource_group.production.name
  location                      = var.location
  subnet_id                     = var.subnet_id
  source_image_id               = data.azurerm_shared_image_version.drupal.id
  vm_size                       = var.vm_size
  instance_count                = var.instance_count
  min_instances                 = var.min_instances
  max_instances                 = var.max_instances
  admin_username                = var.admin_username
  admin_ssh_public_key          = var.admin_ssh_public_key
  os_disk_size_gb               = var.os_disk_size_gb
  health_probe_path             = var.health_probe_path
  health_probe_port             = var.health_probe_port
  enable_autoscaling            = var.enable_autoscaling
  scale_out_cpu_threshold       = var.scale_out_cpu_threshold
  scale_in_cpu_threshold        = var.scale_in_cpu_threshold
  load_balancer_backend_pool_id = var.lb_backend_pool_id
  custom_data                   = var.custom_data

  tags = {
    Environment  = "production"
    ImageVersion = var.image_version
  }
}
