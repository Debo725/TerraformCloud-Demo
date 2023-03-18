##Backend Configuration
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
}

provider "azurerm" {
features {}
}


##Create a Resource Group
resource "azurerm_resource_group" "app_rg1" {
  name     = "KiawiTechSTAGE-RG"
  location = "East US"
}

##Create A VNet
resource "azurerm_virtual_network" "app_vnet" {
  name                = "app-vnet"
  location            = azurerm_resource_group.app_rg1.location
  resource_group_name = azurerm_resource_group.app_rg1.name
  address_space       = ["10.0.0.0/16"]

  depends_on = [
    azurerm_resource_group.app_rg1
  ]
}

##Create a Subnet
  resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet1"
  resource_group_name  = azurerm_resource_group.app_rg1.name
  virtual_network_name = azurerm_virtual_network.app_vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [
    azurerm_virtual_network.app_vnet
  ]
  }

###Create an NSG
resource "azurerm_network_security_group" "app_nsg" {
  name                = "App-NSG"
  location            = azurerm_resource_group.app_rg1.location
  resource_group_name = azurerm_resource_group.app_rg1.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

##Create a NIC
resource "azurerm_network_interface" "app_nic" {
  name                = "appvm1-nic"
  location            = azurerm_resource_group.app_rg1.location
  resource_group_name = azurerm_resource_group.app_rg1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.app_pip.id
  }


  depends_on = [
    azurerm_virtual_network.app_vnet, azurerm_subnet.app_subnet, azurerm_public_ip.app_pip
  ]
}

##Create a Public IP Address
resource "azurerm_public_ip" "app_pip" {
  name                = "appvm-pip"
  resource_group_name = azurerm_resource_group.app_rg1.name
  location            = azurerm_resource_group.app_rg1.location
  allocation_method   = "Static"

}

##Create a Windows VM
resource "azurerm_windows_virtual_machine" "app_vm" {
  name                = "appvm1"
  resource_group_name = azurerm_resource_group.app_rg1.name
  location            = azurerm_resource_group.app_rg1.location
  size                = "Standard_B4ms"
  admin_username      = "ServerAdmin"
  admin_password      = "@Password1234!"
  network_interface_ids = [
    azurerm_network_interface.app_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_nic
  ]
}

