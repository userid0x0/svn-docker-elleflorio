# Alpine Linux with s6 service management
#FROM smebberson/alpine-base:3.2.0
FROM alpine:20230208 AS my-alpine-s6
#FROM alpine:latest AS my-alpine-s6

ARG S6_OVERLAY_VERSION=3.1.4.1 \
    GO_DNSMASQ_VERSION=1.0.7

RUN apk add --no-cache wget xz &&\
    wget --no-check-certificate https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz &&\
	tar -C / -Jxpf s6-overlay-noarch.tar.xz &&\
	rm s6-overlay-noarch.tar.xz &&\
    wget --no-check-certificate https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz &&\
	tar -C / -Jxpf s6-overlay-x86_64.tar.xz &&\
	rm s6-overlay-x86_64.tar.xz &&\
    apk add --no-cache bind-tools curl libcap && \
    wget --no-check-certificate -O /bin/go-dnsmasq https://github.com/janeczku/go-dnsmasq/releases/download/${GO_DNSMASQ_VERSION}/go-dnsmasq-min_linux-amd64 &&\
    chmod +x /bin/go-dnsmasq &&\
    # create user and give binary permissions to bind to lower port
    addgroup go-dnsmasq &&\
    adduser -D -g "" -s /bin/sh -G go-dnsmasq go-dnsmasq &&\
    setcap CAP_NET_BIND_SERVICE=+eip /bin/go-dnsmasq &&\
    apk del wget xz

COPY root /
RUN chmod +x /etc/services.d/resolver/*

ENTRYPOINT ["/init"]

FROM my-alpine-s6


	# Install Apache2 and other stuff needed to access svn via WebDav
	# Install svn
	# Installing utilities for SVNADMIN frontend
	# Create required folders
	# Create the authentication file for http access
	# Getting SVNADMIN interface
COPY iF.SVNAdmin /opt/svnadmin
RUN apk add --no-cache apache2 apache2-ctl apache2-utils apache2-webdav mod_dav_svn &&\
	apk add --no-cache subversion subversion-tools &&\
	apk add --no-cache wget unzip xz &&\
        apk add --no-cache php82 php82-apache2 php82-session php82-json php82-ldap php82-xml &&\	
	sed -i 's/;extension=ldap/extension=ldap/' /etc/php82/php.ini &&\
	mkdir -p /run/apache2/ &&\
	mkdir /home/svn/ &&\
	mkdir /etc/subversion &&\
	touch /etc/subversion/passwd &&\
	ln -s /opt/svnadmin /var/www/localhost/htdocs/svnadmin &&\
	chmod -R 777 /opt/svnadmin/data &&\
    wget --no-check-certificate https://github.com/websvnphp/websvn/archive/refs/tags/2.8.1.zip &&\
	unzip 2.8.1.zip -d /opt &&\
	rm 2.8.1.zip &&\
	mv /opt/websvn-2.8.1 /opt/websvn &&\
	ln -s /opt/websvn /var/www/localhost/htdocs/websvn

# Solve a security issue (https://alpinelinux.org/posts/Docker-image-vulnerability-CVE-2019-5021.html)	
RUN sed -i -e 's/^root::/root:!:/' /etc/shadow

# svnadmin
# Configuration template
ADD svnadmin/data/config.tpl.ini /opt/svnadmin/data/config.tpl.ini

# Add WebSVN configuration
ADD websvn/include/config.php /opt/websvn/include/config.php

# Add services configurations
ADD apache/ /etc/services.d/apache/
ADD subversion/ /etc/services.d/subversion/
RUN chmod +x /etc/services.d/apache/* /etc/services.d/subversion/*

# Add SVNAuth file
ADD subversion-access-control /etc/subversion/subversion-access-control
RUN chmod a+w /etc/subversion/* && chmod a+w /home/svn

# Apache
# Add WebDav configuration
ADD dav_svn.conf /etc/apache2/conf.d/dav_svn.conf
# Add WebSVN 
ADD websvn.conf /etc/apache2/conf.d/websvn.conf

# Set HOME in non /root folder
ENV HOME /home

# Expose ports for http and custom protocol access
EXPOSE 80 443 3690
