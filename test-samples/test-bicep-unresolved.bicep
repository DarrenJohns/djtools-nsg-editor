// Test file: Bicep with parameters that have NO default values
// Expected: Resolution modal should appear for vnetPrefix and dbSubnet

param location string = 'australiaeast'
param vnetPrefix string
param dbSubnet string

var webPort = '443'

resource testNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-unresolved-test'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-From-VNet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: webPort
          sourceAddressPrefix: vnetPrefix
          destinationAddressPrefix: dbSubnet
        }
      }
      {
        name: 'Deny-All'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
