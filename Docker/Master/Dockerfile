FROM ubuntu

RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
RUN echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

COPY . .
RUN chmod +x install.sh && ./install.sh
CMD [ "echo", "'bob'", "&&", "echo", "'ehllo'"]