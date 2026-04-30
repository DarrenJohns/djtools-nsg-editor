param location string

var sourceAddressPrefix = '10.0.0.0/16'
var destinationAddressPrefix = '10.1.0.0/16'

resource nsg_test_01 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-test-01'
  location: location
  properties: {
    securityRules: [
      {
        name: 'rule01'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: sourceAddressPrefix
          destinationAddressPrefix: destinationAddressPrefix
          description: 'Test rule'
        }
      }
    ]
  }
}
