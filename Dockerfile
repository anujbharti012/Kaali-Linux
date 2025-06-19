FROM debian:bookworm-slim

# Set environment variables
ENV LANG=en_US.utf8 \
    DEBIAN_FRONTEND=noninteractive \
    NGROK_VERSION=3.3.5

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
        jq && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
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

# Create startup script that exposes ngrok URL
RUN echo "#!/bin/bash" > /start.sh && \
    echo "service ssh start" >> /start.sh && \
    echo "./ngrok tcp 22 --log=stdout &" >> /start.sh && \
    echo "echo 'Waiting for ngrok to initialize...'" >> /start.sh && \
    echo "sleep 5" >> /start.sh && \
    echo "NGROK_URL=\$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')" >> /start.sh && \
    echo "echo 'Ngrok and SSH started successfully'" >> /start.sh && \
    echo "echo 'SSH via Ngrok: ssh root@\${NGROK_URL#*://}'" >> /start.sh && \
    echo "echo 'Ngrok dashboard: http://localhost:4040'" >> /start.sh && \
    echo "echo 'To keep container running...'" >> /start.sh && \
    echo "while true; do sleep 1000; done" >> /start.sh && \
    chmod +x /start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4040/api/tunnels || exit 1

# Expose ports (including SSH port 22 and ngrok web interface 4040)
EXPOSE 22 4040

# Start the service
CMD ["/bin/bash", "/start.sh"]
