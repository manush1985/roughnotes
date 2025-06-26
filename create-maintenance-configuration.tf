
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id   = ""
}

# 1. Resource Group
resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = local.location
}

# 2. NSG
resource "azurerm_network_security_group" "this" {
  name                = local.nsg_name
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name
}

# 3. VNET
resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
}

# 4. Subnet with NSG association
resource "azurerm_subnet" "this" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

# NSG Association
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# 5. Public IP
resource "azurerm_public_ip" "this" {
  name                = "vm-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# 6. NIC
resource "azurerm_network_interface" "this" {
  name                = "vm-nic"
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

# 7. Windows VM with patch mode enabled
resource "azurerm_windows_virtual_machine" "this" {
  name                = local.vm_name
  resource_group_name = azurerm_resource_group.this.name
  location            = local.location
  size                = local.vm_size
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  network_interface_ids = [azurerm_network_interface.this.id]
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  patch_mode            = "AutomaticByPlatform"  # Enable patching

  source_image_reference {
    publisher = local.vm_image_publisher
    offer     = local.vm_image_offer
    sku       = local.vm_image_sku
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
locals {
  resource_group_name       = "office-poc"
  location                  = "westeurope"
  nsg_name                  = "vnet-app-snet-nsg"
  vnet_name                 = "vnet"
  subnet_name               = "vnet-app-snet"
  vm_name                   = "vm"
  vm_size                   = "Standard_B2s"
  vm_image_offer            = "WindowsServer"
  vm_image_publisher        = "MicrosoftWindowsServer"
  vm_image_sku              = "2019-Datacenter"
  vm_admin_username         = "azureuser"
  vm_admin_password         = "*****"  # Replace with a secure password
  maintenance_config_name   = "patch-maintenance-configuration"
  patch_window_duration     = "03:00"
  patch_time_zone           = "UTC"  # UTC
  patch_classifications     = ["Critical", "Security"]
  # Static start date for maintenance window (next upcoming Sunday at 2 AM)
  # For dynamic scheduling, consider using Azure CLI in local-exec
  maintenance_start_date    = "2025-06-25 00:00"  # Example date: upcoming Sunday at 2 AM
  recur_every               = "7Days"  # Weekly recurrence
}

# 8. Create Maintenance Configuration (scheduled for next Sunday at 2 AM)
# Note: For precise weekly scheduling, consider Azure CLI or external automation.
resource "azurerm_maintenance_configuration" "this" {
  name                = local.maintenance_config_name
  resource_group_name = azurerm_resource_group.this.name
  location            = local.location
  scope               = "InGuestPatch"  # Applies to VM guests
  in_guest_user_patch_mode = "User"

  # Maintenance window
  window {
    start_date_time = local.maintenance_start_date
    duration        = local.patch_window_duration
    time_zone       = local.patch_time_zone
    recur_every     = local.recur_every
  }

  # Enable automatic updates
  install_patches {
    windows {
      classifications_to_include = local.patch_classifications
    }
    reboot = "IfRequired"  # Reboot after patching
  }
}

resource "azurerm_maintenance_assignment_virtual_machine" "this" {
  location                     = azurerm_resource_group.this.location
  maintenance_configuration_id = azurerm_maintenance_configuration.this.id
  virtual_machine_id           = azurerm_windows_virtual_machine.this.id
}


# Output the VM's public IP
output "vm_public_ip" {
  value = azurerm_public_ip.this.ip_address
}

##############

# 5. Public IP
resource "azurerm_public_ip" "b" {
  name                = "vm-public-ip-b"
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# 6. NIC
resource "azurerm_network_interface" "b" {
  name                = "vm-nic-b"
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal-b"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.b.id
  }
}

# 7. Windows VM with patch mode enabled
resource "azurerm_windows_virtual_machine" "b" {
  name                = "vm-b"
  resource_group_name = azurerm_resource_group.this.name
  location            = local.location
  size                = local.vm_size
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  network_interface_ids = [azurerm_network_interface.b.id]
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  patch_mode            = "AutomaticByPlatform"  # Enable patching

  source_image_reference {
    publisher = local.vm_image_publisher
    offer     = local.vm_image_offer
    sku       = local.vm_image_sku
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

}

resource "azurerm_maintenance_assignment_virtual_machine" "b" {
  location                     = azurerm_resource_group.this.location
  maintenance_configuration_id = azurerm_maintenance_configuration.this.id
  virtual_machine_id           = azurerm_windows_virtual_machine.b.id
}