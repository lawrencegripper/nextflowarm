#!/bin/sh
#!/bin/bash

#Install CIFS, JQ, azurecli and docker (used by this script)
#apt-get -y update
#apt-get install python-software-properties apt-transport-https lsb_release curl -y

#Add sources to apt
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 
#add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" 

#echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
#     sudo tee /etc/apt/sources.list.d/azure-cli.list 
#apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893 

#Update and install
#apt-get -y update 
#apt-get install cifs-utils jq azure-cli docker-ce -y 

#Install java
#log "Installing JAVA" $LOGFILE
#apt-get install openjdk-8-jdk -y 

#Add the nextflow user to the docker group. 
#usermod -aG docker $6 
#Nextflow creates files with write permissions only allowed by user that created them
#As we run nextflow under user/group nextflow/nextlow but the docker containers run under root 
#We need to add root to the nextflow user group to give it the correct permissions
#usermod -aG $6 root 
#usermod -aG nogroup root 



#Install nextflow
#log "Installing nextflow" $LOGFILE
#curl -s https://get.nextflow.io | bash 

#Copy the binary to the path to be accessed by users
#cp ./nextflow /usr/local/bin
#chmod -f 777 /usr/local/bin/nextflow #Todo: Review sec implications 

#log "Done with install. "

