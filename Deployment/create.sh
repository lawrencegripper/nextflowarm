#!/bin/sh
#!/bin/bash
# $1 = Azure storage account name

RESOURCE_GROUP=$1
az group create -l westus2 -g $RESOURCE_GROUP
cp ./azuredeploy.parameters.lgpriv.json ./azuredeploy.parameters.lgpriv.$RESOURCE_GROUP.json
sed -i e "s|__JUMPBOXDNS__|$RESOURCE_GROUP|g" ./azuredeploy.parameters.lgpriv.$RESOURCE_GROUP.json
az group deployment create -g $RESOURCE_GROUP --template-file ./azuredeploy.json --parameters @./azuredeploy.parameters.lgpriv.$RESOURCE_GROUP.json
echo "Done: Here are details for connecting and running pipelines"
az group deployment show -g $RESOURCE_GROUP -n azuredeploy --query properties.outputs