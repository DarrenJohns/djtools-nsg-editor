// Test file: Bicep with parameters and variables
// Expected: All param/var references should resolve to their default values

param location string = 'australiaeast'
param environment string = 'production'

var vnetPrefix = '10.0.0.0/16'
var subnetPrefix = '10.0.1.0/24'
var appServerPrefix = '10.0.2.0/24'

resource testNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-VNet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: vnetPrefix
          destinationAddressPrefix: subnetPrefix
        }
      }
      {
        name: 'Allow-HTTPS-From-AppServers'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appServerPrefix
          destinationAddressPrefix: subnetPrefix
        }
      }
      {
        name: 'Allow-RDP-Literal'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '192.168.1.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
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
