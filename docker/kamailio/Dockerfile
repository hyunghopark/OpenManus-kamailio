FROM debian:bullseye-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    kamailio \
    kamailio-mysql-modules \
    kamailio-websocket-modules \
    kamailio-tls-modules \
    kamailio-extra-modules \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration
COPY config/kamailio.cfg /etc/kamailio/kamailio.cfg
COPY config/kamctlrc /etc/kamailio/kamctlrc

# Expose SIP ports
EXPOSE 5060/udp
EXPOSE 5060/tcp
EXPOSE 5061/tcp

# Start Kamailio
CMD ["kamailio", "-DD", "-E"] 