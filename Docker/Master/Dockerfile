#docker build . --build-arg nfUsername=nextflow
FROM ubuntu
ARG nfUsername

#Fix for "Can't locate Term/ReadLine.pm in @INC (you may need to install the Term::ReadLine module)"
ENV DEBIAN_FRONTEND noninteractive 

RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
RUN echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

COPY . .
RUN apt-get -qq update &&\
    #Install CIFS, JQ, Java and ancillary packages
    apt-get install apt-utils software-properties-common python-software-properties apt-transport-https curl cifs-utils jq openjdk-8-jdk -y &&\
    #Add sources to apt for Docker and Azure CLI
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" &&\
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
    tee /etc/apt/sources.list.d/azure-cli.list &&\
    apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893 &&\
    #Update and install Azure CLI & Docker
    apt-get -y update &&\
    apt-get install azure-cli docker-ce -y &&\

    #Write to log
    #log "Installed ancillary packages" $LOGFILE &&\

    #Create Nextflow user
    useradd -m -s /bin/bash $nfUsername &&\

    #Add the Nextflow user to the docker group. 
    usermod -aG docker $nfUsername &&\
    #Nextflow creates files with write permissions only allowed by user that created them
    #As we run Nextflow under user/group Nextflow/Nextflow but the Docker containers run under root 
    #We need to add root to the Nextflow user group to give it the correct permissions
    usermod -aG $nfUsername root &&\

    #Install Nextflow
    #log "Installing Nextflow" $LOGFILE &&\
    curl -s https://get.nextflow.io | bash &&\

    #Copy the binary to the path to be accessed by users
    cp ./nextflow /usr/local/bin &&\
    #Todo: Review sec implications
    chmod -f 777 /usr/local/bin/nextflow &&\

    #log "Install complete" &&\

    #Run initialisation script
    chmod +x init.sh 
    #&& ./init.sh
