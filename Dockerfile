FROM debian:bookworm-slim

# Install minimal requirements
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        openssh-server \
        unzip \
        wget \
        python3 \
        netcat && \
    rm -rf /var/lib/apt/lists/*

# Setup SSH (root:choco)
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd

# Install ngrok
ARG NGROK_TOKEN
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O ngrok.zip && \
    unzip ngrok.zip && \
    echo "authtoken: ${NGROK_TOKEN}" > /ngrok.yml && \
    chmod +x ngrok

# Minimal startup script
RUN echo "#!/bin/sh" > /start.sh && \
    echo "./ngrok tcp 22 --config=ngrok.yml &" >> /start.sh && \
    echo "/usr/sbin/sshd -D &" >> /start.sh && \
    echo "echo 'SSH via ngrok (check logs for URL)'" >> /start.sh && \
    echo "nc -lk -p 10000 -e echo -e 'HTTP/1.1 200 OK\\n\\nSSH available via ngrok (check logs)'" >> /start.sh && \
    chmod +x /start.sh

EXPOSE 10000
CMD ["/start.sh"]
