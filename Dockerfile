FROM debian:bookworm-slim

# Set environment variables
ENV LANG=en_US.utf8 \
    DEBIAN_FRONTEND=noninteractive \
    NGROK_VERSION=3.3.5 \
    PORT=10000

# Install dependencies with cleanup
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        ffmpeg \
        git \
        locales \
        nano \
        python3-pip \
        screen \
        openssh-server \
        unzip \
        wget \
        jq \
        netcat-openbsd && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

# Install Node.js (for simple HTTP server)
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH to bind to all interfaces
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'ListenAddress 0.0.0.0' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd

# Install ngrok with proper config
ARG NGROK_TOKEN
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v${NGROK_VERSION}-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    mkdir -p /root/.config/ngrok && \
    echo "version: 2" > /root/.config/ngrok/ngrok.yml && \
    echo "authtoken: ${NGROK_TOKEN}" >> /root/.config/ngrok/ngrok.yml && \
    echo "region: ap" >> /root/.config/ngrok/ngrok.yml && \
    chmod +x ngrok

# Create a simple HTTP server to satisfy Render's requirements
RUN echo "const express = require('express');" > /server.js && \
    echo "const app = express();" >> /server.js && \
    echo "const port = process.env.PORT || 10000;" >> /server.js && \
    echo "app.get('/', (req, res) => {" >> /server.js && \
    echo "  res.send('SSH access available via ngrok - check logs for connection details');" >> /server.js && \
    echo "});" >> /server.js && \
    echo "app.listen(port, '0.0.0.0', () => {" >> /server.js && \
    echo "  console.log(`Web server listening on port ${port}`);" >> /server.js && \
    echo "});" >> /server.js

# Create startup script
RUN echo "#!/bin/bash" > /start.sh && \
    echo "service ssh start" >> /start.sh && \
    echo "./ngrok tcp 22 --log=stdout &" >> /start.sh && \
    echo "node /server.js &" >> /start.sh && \
    echo "echo 'Waiting for ngrok to initialize...'" >> /start.sh && \
    echo "sleep 5" >> /start.sh && \
    echo "NGROK_URL=\$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')" >> /start.sh && \
    echo "echo 'Ngrok and SSH started successfully'" >> /start.sh && \
    echo "echo 'SSH via Ngrok: ssh root@\${NGROK_URL#*://}'" >> /start.sh && \
    echo "echo 'Web interface: http://localhost:4040'" >> /start.sh && \
    echo "echo 'To keep container running...'" >> /start.sh && \
    echo "while true; do sleep 1000; done" >> /start.sh && \
    chmod +x /start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT} || exit 1

# Expose ports
EXPOSE ${PORT} 22 4040

# Start the service
CMD ["/bin/bash", "/start.sh"]
