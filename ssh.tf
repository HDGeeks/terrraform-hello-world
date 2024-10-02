resource "random_pet" "ssh_key_name" {
  prefix    = "ssh"
  separator = ""
}

resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
}

resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

# Provision to create the PEM file and update SSH config
resource "null_resource" "ssh_key_setup" {
  depends_on = [azurerm_linux_virtual_machine.my_terraform_vm] # Ensure this runs after the VM is created

  provisioner "local-exec" {
    command = <<EOT
      # Create the PEM file with the private key
      echo "${azapi_resource_action.ssh_public_key_gen.output.privateKey}" > ~/.ssh/${random_pet.ssh_key_name.id}.pem
      
      # Set permissions to 400 for the PEM file
      chmod 400 ~/.ssh/${random_pet.ssh_key_name.id}.pem

      # Update the SSH config file if it doesn't already exist
      ssh_config_file=~/.ssh/config

      # Check if the Host entry exists in the SSH config
      if ! grep -q "${random_pet.ssh_key_name.id}" $ssh_config_file; then
        echo "Host ${azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address}" >> $ssh_config_file
        echo "    Hostname ${azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address}" >> $ssh_config_file
        echo "    Port 22" >> $ssh_config_file
        echo "    User azureadmin" >> $ssh_config_file
        echo "    IdentityFile ~/.ssh/${random_pet.ssh_key_name.id}.pem" >> $ssh_config_file
      fi
    EOT
  }
}



output "key_data" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

output "pem_file" {
  description = "Path to the PEM file used for SSH access"
  value       = "~/.ssh/${random_pet.ssh_key_name.id}.pem"
}
