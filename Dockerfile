FROM debian:bookworm-slim

# Install base packages (your original set plus netcat)
RUN apt-get update && \
    apt-get install -y \
        curl \
        ffmpeg \
        git \
        locales \
        nano \
        python3-pip \
        screen \
        ssh \
        unzip \
        wget \
        netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH (root:choco)
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd

# Install ngrok (no extra dependencies)
ARG NGROK_TOKEN
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O ngrok.zip && \
    unzip ngrok.zip && \
    echo "authtoken: ${NGROK_TOKEN}" > /ngrok.yml && \
    chmod +x ngrok

# Minimal startup script
RUN echo "#!/bin/sh" > /start.sh && \
    echo "./ngrok tcp 22 --config=ngrok.yml &" >> /start.sh && \
    echo "/usr/sbin/sshd -D &" >> /start.sh && \
    echo "echo 'SSH access via ngrok (check logs for URL)'" >> /start.sh && \
    echo "while true; do nc -l -p 10000 -c 'echo -e \"HTTP/1.1 200 OK\\n\\nSSH available via ngrok\"'; done" >> /start.sh && \
    chmod +x /start.sh

EXPOSE 10000
CMD ["/start.sh"]
