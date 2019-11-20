# Azure VM - Polynote Server

This is an example ARM template to deploy an Azure virtual machine running [Polynote](https://polynote.org/).

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

## Deploying using the CLI

The following commands can be used to deploy the template from the command line using the [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest).

```bash
# Create a resource group to deploy the virtual machine to
az group create -g <resource group name>

# Deploy the template
az group deployment create \
    -g <resource group name> \
    --template-file .\templates\azuredeploy.json \
    --parameters resourcePrefix='tstvm' clientIpAddress='<your ip address>' vmAdminUser='<admin username>' vmAdminPass='<admin password>' \
    --verbose
```

As Polynote currently does not have any built-in security, the template creates a network security group blocking access except for a given IP address on ports 22 (SSH) and 8192 (Polynote). You can find your IP address using a service such as [ipify](https://www.ipify.org/).

By default the template will deploy a `Standard_D2s_V3` server running Ubuntu 18.04 LTS. The size of the VM can be changed to any of those available in your region which can be found using the following Azure CLI command.

```bash
az vm list-sizes -o table
```

When the deployment is complete the polynote service should be started, so you can point your browser to `http://<vm name>.<region>.cloudapp.azure.com:8192` and start playing. You can also SSH onto the virtual machine and have a look around.

_N.B._ The default port for Polynote is `8192`, if you want to change this you will need to modify the YAML configuration file as per the [documentation](https://polynote.org/docs/01-installation.html).

You can find the IP address/DNS name for your VM either via the Azure Portal or from the command line.

```bash
# Get the VM name
az vm list -g <resource group name> -o table

# Get the fully-qualified domain name
az network public-ip show -g <resource group name> -n <vm name> --query "dnsSettings.fqdn"
```

## Available VM sizes

If you want to filter this list based on number of cores or memory available then you can do this using the `--query` parameter which utilizes [JMESPath](http://jmespath.org/). Remember to change the location to the Azure region you want to deploy to.

_N.B. All commands are outputting in a table format for ease of reading._

### Getting available locations

You can list the locations available to you as an option using the Azure CLI as follows.

```bash
az account list-locations --output table
```

### Querying for VM sizes

For example, to find all [DS_v3 series](https://docs.microsoft.com/azure/virtual-machines/linux/sizes-general#dsv3-series-1) sizes with more than 8Gb of memory in North Europe you could use the following query.

```bash
az vm list-sizes --location northeurope --query "[?starts_with(name, 'Standard_D') && ends_with(name, 's_v3') && memoryInMb > `8192`]" -o table
```

**REMEMBER** if you're using Powershell to query using the Azure CLI you will need to escape the back ticks (see the memory part of the query below).

```powershell
az vm list-sizes --location northeurope --query "[?starts_with(name, 'Standard_D') && ends_with(name, 's_v3') && memoryInMb > ``8192``]" -o table
```

Based on my own subscription this outputs the following (at the time of writing):

Name             | NumberOfCores   | OsDiskSizeInMb   | ResourceDiskSizeInMb   | MemoryInMb   | MaxDataDiskCount
---------------- | --------------- | ---------------- | ---------------------- | ------------ | ------------------
Standard_D4s_v3  | 4               | 1047552          | 32768                  | 16384        | 8
Standard_D8s_v3  | 8               | 1047552          | 65536                  | 32768        | 16
Standard_D16s_v3 | 16              | 1047552          | 131072                 | 65536        | 32
Standard_D32s_v3 | 32              | 1047552          | 262144                 | 131072       | 32
Standard_D48s_v3 | 48              | 1047552          | 393216                 | 196608       | 32
Standard_D64s_v3 | 64              | 1047552          | 524288                 | 262144       | 32
