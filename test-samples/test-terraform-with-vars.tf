# Test file: Terraform with variables and locals
# Expected: All var/local references should resolve to their defaults

variable "location" {
  default = "australiaeast"
  type    = string
}

variable "web_subnet" {
  default = "10.20.1.0/24"
  type    = string
}

variable "api_subnet" {
  default = "10.20.2.0/24"
  type    = string
}

locals {
  nsg_name   = "nsg-terraform-test"
  mgmt_range = "172.16.0.0/16"
}

resource "azurerm_network_security_group" "test" {
  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-HTTP-From-Web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.web_subnet
    destination_address_prefix = var.api_subnet
  }

  security_rule {
    name                       = "Allow-SSH-From-Mgmt"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.mgmt_range
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
