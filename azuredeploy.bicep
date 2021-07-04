@maxLength(5)
@description('Prefix used for naming resources')
param resourcePrefix string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
])
@description('Type of storage account to deploy')
param storageAccountSku string = 'Standard_RAGRS'

@description('IP address to permit access to')
param clientIpAddress string

@description('SKU for the virtual machine')
param vmSize string = 'Standard_D2s_v3'

@description('Admin username for the virtual machine')
param vmAdminUser string

@secure()
@description('')
param vmAdminPass string

@description('Remote branch to use for picking up script files, defaults to \'main\'')
param deploymentBranch string = 'main'

@allowed([
  '0.3.10'
  '0.3.11'
  '0.3.12'
  '0.4.0'
  '0.4.1'
  '0.4.2'
])
@description('The version of polynote to deploy')
param polynoteVersion string = '0.4.2'

var location = resourceGroup().location
var resourceSuffix = uniqueString(resourceGroup().id)               // Defines a unique resource suffix based on the resource group id
var storageAccountName = '${resourcePrefix}data${resourceSuffix}'   // Attempt to ensure that each storage account is uniquely named
var containerName = 'data'
var nsgName = '${resourcePrefix}-nsg${resourceSuffix}'
var vnetName = '${resourcePrefix}-vnet${resourceSuffix}'
var vnetAddresses = '10.10.0.0/16'
var defaultSubnetAddresses = '10.10.1.0/24'
var vmName = '${resourcePrefix}-vm-${resourceSuffix}'
var vmPublicIpName = '${vmName}-ip'
var vmNicName = '${vmName}-nic'
var vmAutoShutdownName = 'shutdown-computevm-${vmName}'

/**
 * Storage account used as a mount point for the VM, and to hold boot diagnostic information. This
 * should ideally be two separate accounts in a production deployment
 */
resource storage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountSku
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        queue: {
          enabled: true
        }
        table: {
          enabled: true
        }
      }
    }
  }
}

/**
 * Creates a container which is mounted by the VM later
 */
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${storage.name}/default/${containerName}'
}

/**
 * Creates a network security group with some basic rules to allow external access
 * from the client location
 */
resource nsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH_Client'
        properties: {
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '${clientIpAddress}/32'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowPolynote_Client'
        properties: {
          priority: 200
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8192'
          sourceAddressPrefix: '${clientIpAddress}/32'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSparkUI_Client'
        properties: {
          priority: 300
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '4040'
          sourceAddressPrefix: '${clientIpAddress}/32'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
    ]
  }
}

/**
 * Public IP address for the VM. Created as a basic SKU so that we can use dynamic allocation of addresses
 * which we can get away with because we're creating a domain label for the VM
 */
resource pip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: vmPublicIpName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'
    idleTimeoutInMinutes: 20
    dnsSettings: {
      domainNameLabel: vmName
    }
  }
}

/**
 * Creates a new VNET with the default subnet. Address prefixes are defined as variables if they need
 * to be changed
 */
resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddresses
      ]
    }
    enableVmProtection: true
    enableDdosProtection: false
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: defaultSubnetAddresses
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

/**
 * Creates the network interface and associates it with the public IP address and default subnet
 */
resource nic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: vmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: pip.id
          }
          subnet: {
            id: '${vnet.id}/subnets/default'
          }
        }
      }
    ]
  }
}

/** 
 * Deploys a Linux VM running Ubuntu. The bulk of the work is done with the setup script which
 * is executed as a custom script
 */
resource vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmName
  location: location
  properties: {
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUser
      adminPassword: vmAdminPass
      allowExtensionOperations: true
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        diskSizeGB: 30
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storage.properties.primaryEndpoints.blob
      }
    }
  }

  /**
   * The custom script which configures Polynote and dependencies
   */
  resource scriptExt 'extensions' = {
    name: 'config-app'
    location: location
    properties: {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.0'
      autoUpgradeMinorVersion: true
      protectedSettings: {
        commandToExecute: 'sh setup.sh ${vmAdminUser} ${storage.name} ${listKeys(storage.id, storage.apiVersion).keys[0].value} ${containerName} ${polynoteVersion}'
        fileUris: [
          'https://raw.githubusercontent.com/dazfuller/azure-arm-polynote-vm/${deploymentBranch}/scripts/setup.sh'
          'https://raw.githubusercontent.com/dazfuller/azure-arm-polynote-vm/${deploymentBranch}/scripts/polynote-server.service'
          'https://raw.githubusercontent.com/dazfuller/azure-arm-polynote-vm/${deploymentBranch}/scripts/demo.ipynb'
        ]
      }
    }
  }
}

/**
 * Auto-shutdown for the VM to prevent over-spend on resources
 */
resource shutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: vmAutoShutdownName
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '2000'
    }
    timeZoneId: 'UTC'
    notificationSettings: {
      status: 'Disabled'
    }
    targetResourceId: vm.id
  }
}

// Return the fully qualified domain name of the public IP resource of the VM
output vmFqdn string = pip.properties.dnsSettings.fqdn
