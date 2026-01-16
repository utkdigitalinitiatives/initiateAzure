variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

# Image Gallery configuration
variable "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  type        = string
}

variable "gallery_resource_group_name" {
  description = "Resource group containing the Azure Compute Gallery"
  type        = string
}

variable "image_name" {
  description = "Name of the image definition in the gallery"
  type        = string
  default     = "drupal-rocky-linux-9"
}

variable "image_version" {
  description = "Version of the image to deploy (e.g., 1.0.0, 2024.01.15)"
  type        = string
}

# Networking
variable "subnet_id" {
  description = "ID of the subnet where the VMSS instances will be deployed"
  type        = string
}

# VM configuration
variable "vm_size" {
  description = "Size of the VM instances"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "instance_count" {
  description = "Default number of instances for the VMSS"
  type        = number
  default     = 2
}

variable "min_instances" {
  description = "Minimum number of instances for autoscaling"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of instances for autoscaling"
  type        = number
  default     = 10
}

variable "admin_username" {
  description = "Admin username for the VMs"
  type        = string
  default     = "drupaladmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for admin access"
  type        = string
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 64
}

# Health probe configuration
variable "health_probe_path" {
  description = "Path for the health probe endpoint"
  type        = string
  default     = "/health"
}

variable "health_probe_port" {
  description = "Port for the health probe"
  type        = number
  default     = 80
}

# Autoscaling configuration
variable "enable_autoscaling" {
  description = "Enable autoscaling for the VMSS"
  type        = bool
  default     = true
}

variable "scale_out_cpu_threshold" {
  description = "CPU percentage threshold to trigger scale out"
  type        = number
  default     = 75
}

variable "scale_in_cpu_threshold" {
  description = "CPU percentage threshold to trigger scale in"
  type        = number
  default     = 25
}

# Load balancer integration
variable "lb_backend_pool_id" {
  description = "Load balancer backend pool ID (for Front Door integration)"
  type        = string
  default     = null
}

# Custom initialization
variable "custom_data" {
  description = "Custom data script (cloud-init) for VM initialization"
  type        = string
  default     = null
}
