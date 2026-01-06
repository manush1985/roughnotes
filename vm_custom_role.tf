# 1. (Same as before) The Custom Role
resource "azurerm_role_definition" "vm_start_stop" {
  name        = "VM Start Stop Custom Role"
  scope       = data.azurerm_subscription.current.id
  description = "Can read, start, and deallocate VMs."

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/deallocate/action"
    ]
    not_actions = []
  }
  assignable_scopes = [ data.azurerm_subscription.current.id ]
}

# 2. (CHANGED) Assign to the Resource Group, not the VM
resource "azurerm_role_assignment" "rg_level_assignment" {
  # This allows the UAMI to list ALL VMs in this group
  scope                = azurerm_resource_group.example.id 
  role_definition_id   = azurerm_role_definition.vm_start_stop.role_definition_resource_id
  principal_id         = azurerm_user_assigned_identity.vm_operator.principal_id
}
