FROM 		debian:bookworm

ARG			DOMAIN_NAME
ARG 		CERTS_KEY
ARG			CERTS_CRT

RUN 		apt -y update && apt -y upgrade
RUN 		apt -y install nginx openssl 

RUN 		openssl req -x509 -sha256 -nodes \
			-newkey rsa:4096 \
			-days 365 \
			-subj "/C=TR/ST=Istanbul/L=Istanbul/O=42Istanbul/OU=Inception/CN=${DOMAIN_NAME}" \
			-keyout ${CERTS_KEY} \
			-out ${CERTS_CRT} 

COPY 		./conf/https.conf /etc/nginx/conf.d/
RUN			sed -i "s|INSERT_DOMAIN_NAME_HERE|${DOMAIN_NAME}|g" /etc/nginx/conf.d/https.conf
RUN 		sed -i "s|INSERT_KEY_PATH_HERE|${CERTS_KEY}|g" /etc/nginx/conf.d/https.conf
RUN 		sed -i "s|INSERT_CRT_PATH_HERE|${CERTS_CRT}|g" /etc/nginx/conf.d/https.conf

EXPOSE 		443

ENTRYPOINT	[ "nginx", "-g", "daemon off;" ]