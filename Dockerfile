FROM debian:bookworm-slim

# Set environment variables
ENV LANG=en_US.utf8 \
    DEBIAN_FRONTEND=noninteractive

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
        wget && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:choco' | chpasswd

# Ngrok setup
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip && \
    mkdir -p /root/.config/ngrok && \
    echo "authtoken: ${NGROK_TOKEN}" > /root/.config/ngrok/ngrok.yml && \
    chmod +x ngrok

# Create startup script
RUN echo "#!/bin/bash" > /start.sh && \
    echo "service ssh start" >> /start.sh && \
    echo "./ngrok tcp 22 &" >> /start.sh && \
    echo "echo 'Ngrok and SSH started'" >> /start.sh && \
    echo "tail -f /dev/null" >> /start.sh && \
    chmod +x /start.sh

# Expose ports (including SSH port 22)
EXPOSE 22 80 8888 8080 443 5130-5135 3306

# Start the service
CMD ["/bin/bash", "/start.sh"]
