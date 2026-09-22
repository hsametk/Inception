# Base image
FROM 		debian:bookworm

# Define build arguments passed from docker-compose.yml
ARG			DOMAIN_NAME
ARG 		CERTS_KEY
ARG			CERTS_CRT

# Update and upgrade system & install Nginx and OpenSSL
RUN 		apt -y update && apt -y upgrade
RUN 		apt -y install nginx openssl 

# Generate self-signed certificate
RUN 		openssl req -x509 -sha256 -nodes \
			-newkey rsa:4096 \
			-days 365 \
			-subj "/C=TR/ST=Istanbul/L=Istanbul/O=42Istanbul/OU=Inception/CN=${DOMAIN_NAME}" \
			-keyout ${CERTS_KEY} \
			-out ${CERTS_CRT} 

# Copy configuration file
COPY 		./conf/https.conf /etc/nginx/conf.d/
RUN			sed -i "s|INSERT_DOMAIN_NAME_HERE|${DOMAIN_NAME}|g" /etc/nginx/conf.d/https.conf
RUN 		sed -i "s|INSERT_KEY_PATH_HERE|${CERTS_KEY}|g" /etc/nginx/conf.d/https.conf
RUN 		sed -i "s|INSERT_CRT_PATH_HERE|${CERTS_CRT}|g" /etc/nginx/conf.d/https.conf

# Expose ports
EXPOSE 		443

# Run NGINX
ENTRYPOINT	[ "nginx", "-g", "daemon off;" ]