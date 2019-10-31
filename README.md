# Azure VM - Polynote Server

This is an example ARM template to deploy an Azure virtual machine running [Polynote](https://polynote.org/).

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

Once deployed you can SSH onto the virtual machine and start the server simply by executing the following (after finding the DNS entry for the Public IP deployed).

```bash
polynote
```

After this you can navigate to the server from your web browser (check website for compatibility) at http://<fully qualified domain name>:8192
