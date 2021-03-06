FROM alpine:3.7

#Installing SSH, NGINX, PHP, MYSQL, ELASTICSEARCH, REDIS, RABBITMQ, VARNISH
RUN apk update && apk --update --no-cache add openssh \
    curl \
    dcron \
    wget \
    bash \
    openjdk8-jre \
    su-exec \
    ca-certificates \
    gettext \
    procps \
    git \
    openssh \
    mysql \
    mysql-client \
    php7 \
    php7-apcu \
    php7-bcmath \
    php7-bz2 \
    php7-cgi \
    php7-ctype \
    php7-curl \
    php7-dom \
    php7-fpm \
    php7-ftp \
    php7-gd \
    php7-iconv \
    php7-json \
    php7-mbstring \
    php7-oauth \
    php7-opcache \
    php7-openssl \
    php7-pcntl \
    php7-pdo \
    php7-pdo_mysql \
    php7-phar \
    php7-redis \
    php7-session \
    php7-simplexml \
    php7-tokenizer \
    php7-xdebug \
    php7-xml \
    php7-xmlwriter \
    php7-zip \
    php7-zlib \
    php7-zmq \
    php7-intl \
    php7-xsl \
    php7-soap \
    php7-mcrypt \
    redis \
    erlang-asn1 \
    erlang-hipe \
    erlang-crypto \
    erlang-eldap \
    erlang-inets \
    erlang-mnesia \
    erlang \
    erlang-os-mon \
    erlang-public-key \
    erlang-sasl \
    erlang-ssl \
    erlang-syntax-tools \
    erlang-xmerl \
    varnish && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer 

# Adding users and groups for Nginx, MySQl, Elastisearch, Rabbitmq
RUN echo 'root:root' | chpasswd && \
    adduser -D -u 1000 -g 1000 -s /bin/sh -h /var/www/html nginx && echo 'nginx:nginx' | chpasswd && \
    addgroup mysql mysql && \
    adduser -D -h /usr/share/elasticsearch elasticsearch && \
    addgroup -S rabbitmq && adduser -S -h /var/lib/rabbitmq -G rabbitmq rabbitmq

# Setting configuration for SSH, Nginx, PHP, MySQl. Installing nginx here as user has to be created as main user with UID 1000. 
RUN ssh-keygen -A &&\
    sed -i 's/#PermitRootLogin.*/PermitRootLogin\ yes/g' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication\ yes/PubkeyAuthentication\ yes/g' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication\ yes/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config && \
    sed -ie 's/#Port 22/Port 22/g' /etc/ssh/sshd_config && \
    sed -ri 's/#HostKey \/etc\/ssh\/ssh_host_key/HostKey \/etc\/ssh\/ssh_host_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_dsa_key/HostKey \/etc\/ssh\/ssh_host_dsa_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ecdsa_key/HostKey \/etc\/ssh\/ssh_host_ecdsa_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/g' /etc/ssh/sshd_config && \
    sed -i 's/memory_limit = 128M/memory_limit = -1/g' /etc/php7/php.ini && \
    apk --update --no-cache add nginx && \ 
    mkdir -p /var/www/html && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /run/nginx && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/lib/nginx /var/www && \
    chown -R nginx:nginx /var/tmp/nginx /run/nginx && \
    rm -rf /etc/nginx/conf.d/default.conf 
COPY ./php-fpm-www.conf /etc/php7/php-fpm.d/www.conf
COPY ./nginx.conf.template /nginx.conf.template
COPY ./nginx.conf /etc/nginx/conf.d/
WORKDIR /var/www/html

# Setting up configuration for Elasticsearch
RUN cd /tmp \
    && wget --progress=bar:force -O elasticsearch.tar.gz "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.6.16.tar.gz" \
    && tar -xf elasticsearch.tar.gz \
    && mkdir -p /usr/share/elasticsearch \
    && mv elasticsearch-5.6.16/* /usr/share/elasticsearch \
    && rm -rf /tmp/elasticsearch.tar.gz \
    && sed -ie 's/-Xms2g/-Xms256m/g' /usr/share/elasticsearch/config/jvm.options \
    && sed -ie 's/-Xmx2g/-Xmx256m/g' /usr/share/elasticsearch/config/jvm.options \
# Setting up configuration for Rabbitmq
    && mkdir -p /opt/rabbitmq \
    && wget -O rabbitmq-server.tar.xz "https://github.com/rabbitmq/rabbitmq-server/releases/download/rabbitmq_v3_6_12/rabbitmq-server-generic-unix-3.6.12.tar.xz" \
    && tar --extract --verbose --file rabbitmq-server.tar.xz --directory /opt/rabbitmq --strip-components 1 \
    && rm -f rabbitmq-server.tar.xz \
    && mkdir -p /var/lib/rabbitmq /etc/rabbitmq  

COPY elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml

# Assigning permissions for respective  directories of Elasticsearch and Rabbitmq
RUN chown -R elasticsearch:elasticsearch /usr/share/elasticsearch && \
    chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /etc/rabbitmq && chmod -R 777 /var/lib/rabbitmq /etc/rabbitmq

# Copying config file of Redis
COPY redis.conf /etc/redis.conf

# Setting up Varnish configuration
COPY default.vcl /etc/varnish/default.vcl

# Exposing all the ports
EXPOSE 3306 9000 6379 80 22 5672 15672 9200 9300 8080

# Setting up environmental variables
ENV PATH /opt/rabbitmq/sbin:/usr/share/elasticsearch/bin:$PATH

COPY scripts/start.sh /usr/local/bin/start.sh

ENTRYPOINT [ "sh", "/usr/local/bin/start.sh" ]
