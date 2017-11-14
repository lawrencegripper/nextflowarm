read RESOURCE_GROUP
az group create -l westus2 -g $RESOURCE_GROUP
az group deployment create -g $RESOURCE_GROUP --template-file ./azuredeploy.json --parameters @./azuredeploy.parameters.lgpriv.json --no-wait 