terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.57"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend configuration for Terraform state
  # Uncomment and configure for your Azure Storage backend
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstateaccount"
  #   container_name       = "tfstate"
  #   key                  = "poc/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  environment = "poc"
  common_tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Application = "drupal"
    Purpose     = "proof-of-concept"
  }
}

# Generate random hash salt for Drupal security
resource "random_password" "drupal_hash_salt" {
  length  = 64
  special = false
}

# Generate random Drupal admin password if not provided
resource "random_password" "drupal_admin" {
  length  = 24
  special = true
}

# Resource group for all PoC resources
resource "azurerm_resource_group" "poc" {
  name     = "drupal-poc-rg"
  location = var.location
  tags     = local.common_tags
}

# Data source: Get image version from Azure Compute Gallery
data "azurerm_shared_image_version" "drupal" {
  count               = var.use_gallery_image ? 1 : 0
  name                = var.image_version
  image_name          = var.image_name
  gallery_name        = var.gallery_name
  resource_group_name = var.gallery_resource_group_name
}

# Networking: VNet, subnets, NSG with Load Balancer rules
module "networking" {
  source = "../../modules/networking"

  environment                = local.environment
  resource_group_name        = azurerm_resource_group.poc.name
  location                   = var.location
  vnet_address_space                       = var.vnet_address_space
  web_subnet_address_prefix                = var.web_subnet_prefix
  private_endpoints_subnet_address_prefix  = var.private_endpoints_prefix
  enable_load_balancer_rules               = true   # PoC uses LB instead of Front Door
  enable_front_door_rules                  = false  # Disable Front Door rules for PoC

  tags = local.common_tags
}

# Load Balancer: Public Standard LB for PoC
module "load_balancer" {
  source = "../../modules/load-balancer"

  environment         = local.environment
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.location
  dns_label           = var.lb_dns_label
  health_probe_path   = var.health_probe_path
  enable_https        = var.enable_https
  enable_outbound_rule = true

  tags = local.common_tags
}

# PostgreSQL: Burstable tier for PoC
module "postgresql" {
  source = "../../modules/postgresql"

  environment            = local.environment
  resource_group_name    = azurerm_resource_group.poc.name
  location               = var.location
  sku_name               = var.postgresql_sku
  storage_mb             = var.postgresql_storage_mb
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password
  database_name          = var.db_name
  postgresql_version     = var.postgresql_version
  backup_retention_days  = 14  # Minimal for PoC
  geo_redundant_backup_enabled = false
  allow_azure_services   = true

  # Public access for PoC (add your IP for management)
  allowed_ip_addresses = var.db_allowed_ips

  tags = local.common_tags
}

# Blob Storage: Drupal media files
module "blob_storage" {
  source = "../../modules/blob-storage"

  environment           = local.environment
  resource_group_name   = azurerm_resource_group.poc.name
  location              = var.location
  container_name        = "drupal-media"
  replication_type      = "LRS"  # Minimal for PoC
  soft_delete_retention_days = 7
  enable_versioning     = false  # Not needed for PoC

  # Two-pass deployment: set false initially, true after VMSS exists
  enable_vmss_blob_access = var.enable_vmss_blob_access
  vmss_principal_id       = var.enable_vmss_blob_access ? module.vmss.vmss_identity_principal_id : null

  tags = local.common_tags
}

# VMSS: Single instance for PoC with rolling updates
module "vmss" {
  source = "../../modules/drupal-vmss"

  environment         = local.environment
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.location
  subnet_id           = module.networking.web_subnet_id

  # Image source: gallery or marketplace fallback
  source_image_id = var.use_gallery_image ? data.azurerm_shared_image_version.drupal[0].id : null

  vm_size        = var.vm_size
  instance_count = 1  # Minimal for PoC
  min_instances  = 1
  max_instances  = 2

  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key
  os_disk_size_gb      = var.os_disk_size_gb

  health_probe_path = var.health_probe_path
  health_probe_port = 80

  enable_autoscaling = false  # Not needed for PoC

  # Connect to Load Balancer
  load_balancer_backend_pool_id = module.load_balancer.backend_pool_id

  # Cloud-init with database, storage, and Drupal configuration
  custom_data = templatefile("${path.module}/cloud-init.tftpl", {
    db_host                = module.postgresql.fqdn
    db_name                = module.postgresql.database_name
    db_user                = var.db_admin_username
    db_password            = var.db_admin_password
    storage_account        = module.blob_storage.storage_account_name
    storage_container      = module.blob_storage.container_name
    storage_endpoint       = module.blob_storage.primary_blob_endpoint
    storage_key            = module.blob_storage.primary_access_key
    hash_salt              = random_password.drupal_hash_salt.result
    lb_fqdn                = module.load_balancer.public_ip_fqdn
    drupal_admin_password  = var.drupal_admin_password != null ? var.drupal_admin_password : random_password.drupal_admin.result
  })

  tags = merge(local.common_tags, {
    ImageVersion = var.use_gallery_image ? var.image_version : "marketplace"
  })
}
