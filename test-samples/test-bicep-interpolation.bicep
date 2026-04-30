// Test file: Bicep with string interpolation in rule values
param addressPrefix string = '10.0'
param env string = 'prod'

var webSubnet = '${addressPrefix}.1.0/24'
var dbSubnet = '${addressPrefix}.2.0/24'

resource testNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${env}-web'
  location: 'australiaeast'
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '${addressPrefix}.0.0/16'
          destinationAddressPrefix: '${addressPrefix}.1.0/24'
        }
      }
      {
        name: 'Allow-DB-From-Web'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '${addressPrefix}.1.0/24'
          destinationAddressPrefix: '${addressPrefix}.2.0/24'
        }
      }
    ]
  }
}
