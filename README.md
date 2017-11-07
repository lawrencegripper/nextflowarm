<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Flawrencegripper%2Fnextflowarm%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

Nextflow on Azure
======

## What is Nextflow?
Nextflow enables scalable and reproducible scientific workflows using software containers. It allows the adaptation of pipelines written in the most common scripting languages.

Its fluent DSL simplifies the implementation and the deployment of complex parallel and reactive workflows on clouds and clusters.

## What is the Purpose of this Project?
To enable native support for Nextflow on Azure.

## What is the status of the Project?
Currently this is a work in progress, see the issues tab to understand limitations. 

## The Solution
This Azure Resource Manager template and the accompanying script deploys an Azure Virtual Machine Scale Set hosting Docker and Nextflow for running scientific pipelines. 

The cluster consists of one jumpbox VM (master node) plus 1-100 (limit can be lifted by raising a support ticket) slave nodes in a Scale Set, using Azure Files as shared storage. Users can submit Nextflow workstreams to the master node for execution on the slave nodes.

## Solution Breakdown
* azuredeploy.json:
    * Creates a new resource group, to which it deploys:
        * Storage account
        * VNet and subnet
        * Jumpbox VM
        * N slave VMs in a Scale Set
    * Installs Docker on all VMs as part of the deployment (using DockerExtension from Microsoft.Azure.Extensions)
    * All VMs are then configured to run Nextflow via script (see below for details)
* Scripts/init.sh
    * Installs CIFS and JQ
    * Tries to create an Azure File Share in the new storage account (this will only succeed once, subsequent attempts will silently fail without causing an error)
    * Mounts this as a shared disk for Nextflow. This implementation supports symlinks and FIFO.
    * Installs OpenJDK
    * Installs Nextflow and configures it to use the mounted Azure Files share.
    
## Deploying 

### GUI

Click the 'Deploy to Azure' button and follow the instructions provided. 
On step 3, once the resources are deployed, you'll see a 'Manage your resources' button. 
Click this button then select 'Deployments', click the deployment and you'll see the connection details and an example command in the 'Output' section. 

[Connection process video](https://1drv.ms/v/s!AgO58DGl6B7Rqu9y1ahnXrLlSn0M_g)

Once deployed you can scale the cluster by selecting the VM Scale set and changing the instance count. 

[Scaling video](https://1drv.ms/v/s!AgO58DGl6B7Rqu9wVAqAD5RnJRYSDg)

## Debugging Cluster

The cluster is created as a 'Deployment' under a resource group. If issues occur, the deployment will provide logs and error details. This can be accessed in the portal as follows:

[Debugging cluster video](https://1drv.ms/f/s!AgO58DGl6B7Rg-NyegXiV8cBhdxgKw)

In most cases a good first step is to delete the resource group and redeploy to rule out transient issues.  

In addition to this, logs are created during the setup of the nodes and master. These are stored in the storage account created for the cluster. You easily access these by installing [Azure Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) and browsing the content under '[ResourceGroupUsed]/nfstoragexxxxxxx/File Shares/sharedstorage/logs'. Here is an example:

[Cluster logs video](https://1drv.ms/v/s!AgO58DGl6B7Rqu9xp6uN8Nufc5mJiA)

## Custom Image 

The template supports using a Ubuntu 16 LTS based custom image for the master and nodes. 

Once you have created your image retrieve it's `id` using the azcli. For example run this command, it will list the IDs of your custom images:

 `az image list --query [].id` 

Now update the example parameters file [azuredpeloy.customimage.parameters.json](./azuredeploy.customimage.parameters.json#L16) to use this ID and set any other parameters you require (password, dnsname etc). 

You can then deploy your Nextflow cluster as follows:

 `az group deployment create -g [your_resource_group_here] --template-file ./azuredeploy.json --parameters @azuredeploy.customimage.parameters.json`

 