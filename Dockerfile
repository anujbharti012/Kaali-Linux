FROM debian:bookworm

# Update & install required packages
RUN apt-get update -y && apt-get upgrade -y && apt-get install -y sudo curl ffmpeg git locales nano python3-pip screen ssh unzip wget gnupg

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js 21
RUN curl -fsSL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# NGROK setup
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && \
    rm ngrok.zip

# Create startup script
RUN echo "./ngrok config add-authtoken ${NGROK_TOKEN}" >> /start && \
    echo "./ngrok tcp --region ap 22 &>/dev/null &" >> /start && \
    mkdir -p /run/sshd && \
    echo '/usr/sbin/sshd -D' >> /start && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo root:kaal | chpasswd && \
    chmod 755 /start

# Expose ports
EXPOSE 22 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306

# Run the startup script
CMD ["/start"]
