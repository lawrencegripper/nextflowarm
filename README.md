[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

Nextflow on Azure
======

## What is Nextflow?
Nextflow enables scalable and reproducible scientific workflows using software containers. It allows the adaptation of pipelines written in the most common scripting languages.

Its fluent DSL simplifies the implementation and the deployment of complex parallel and reactive workflows on clouds and clusters.

## What is the Purpose of this Project?
To enable native support for Nextflow on Azure.

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

# GUI

Click the 'Deploy to Azure' button and follow the steps. 
On step 3, once the resources are deployed, you'll see a 'Manage your resources' button. 
Click this button then select 'Deployments', click the deployment and you'll see the connection details and an example command in the 'Output' section. 

Here is a quick video showing the process:

[![Watch the video](https://raw.github.com/GabLeRoux/WebMole/master/ressources/WebMole_Youtube_Video.png)](https://1drv.ms/v/s!AgO58DGl6B7Rqu9y1ahnXrLlSn0M_g)

Once deployed you can scale the cluster by selecting the VM Scale set and changing the instance count. 

[![Watch the video](https://raw.github.com/GabLeRoux/WebMole/master/ressources/WebMole_Youtube_Video.png)](https://1drv.ms/v/s!AgO58DGl6B7Rqu9wVAqAD5RnJRYSDg)

## Debugging Cluster

The cluster is created as a 'Deployment' under a resource group. If issues occur, the deployment will provide logs and error details. This can be access as follows in the portal:

[![Watch the video](https://raw.github.com/GabLeRoux/WebMole/master/ressources/WebMole_Youtube_Video.png)](https://1drv.ms/f/s!AgO58DGl6B7Rg-NyegXiV8cBhdxgKw)

In most cases a good first step is to delete the resource group and redeploy to rule out transient issues.  

In addition to this, logs are created during the setup of the nodes and master. These are stored on the storage account created for the cluster. You easily access these by install [Azure Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) and browsing the content under '[ResourceGroupUsed]/nfstoragexxxxxxx/File Shares/sharedstorage/logs'. Here is an example:

[![Watch the video](https://raw.github.com/GabLeRoux/WebMole/master/ressources/WebMole_Youtube_Video.png)](https://1drv.ms/v/s!AgO58DGl6B7Rqu9xp6uN8Nufc5mJiA)
