FROM ubuntu

COPY . .
RUN chmod +x init.sh
RUN ./init.sh
RUN docker pull redis

CMD [ "nextflow", "node", "-bg", "-cluster.join", "path:/mnt/cifs/cluster"]