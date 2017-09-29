Nextflow on Azure
======

## What is Nextflow?
Nextflow enables scalable and reproducible scientific workflows using software containers. It allows the adaptation of pipelines written in the most common scripting languages.

Its fluent DSL simplifies the implementation and the deployment of complex parallel and reactive workflows on clouds and clusters.

## What is the Purpose of this Project?
To enable native support for Nextflow on Azure.

## The Solution
This Azure Resource Manager template and the accompanying scripts deploy an Azure Virtual Machine Scale Set hosting Docker and Nextflow for running scientific pipelines. 

The cluster consists of one jumpbox VM (master node) plus 1-100 (limit can be lifted) slave nodes in a Scale Set, using Azure Files as shared storage. Users can submit Nextflow workstreams to the master node for running on the slave nodes.

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


[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)