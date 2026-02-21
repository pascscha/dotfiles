FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y sudo curl && rm -rf /var/lib/apt/lists/* && \
    useradd -m -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER devuser
WORKDIR /home/devuser

CMD ["/bin/bash"]
