FROM luotaoruby/jenkins-ssh-ruby-slave:ruby-2.3.8

RUN groupadd -r mysql && useradd -r -g mysql mysql

ENV GOSU_VERSION 1.7
RUN set -x \
      && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
      && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
      && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
      && export GNUPGHOME="$(mktemp -d)" \
      && gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
      && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
      && gpgconf --kill all \
      && rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
      && chmod +x /usr/local/bin/gosu \
      && gosu nobody true
      # && apt-get purge -y --auto-remove ca-certificates wget

RUN apt-get update && apt-get install -y --no-install-recommends \
        pwgen \
        openssl \
        perl \
      && rm -rf /var/lib/apt/lists/*


RUN set -ex; \
  key='A4A9406876FCBD3C456770C88C718D3B5072E1F5'; \
  export GNUPGHOME="$(mktemp -d)"; \
  gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  gpg --batch --export "$key" > /etc/apt/trusted.gpg.d/mysql.gpg; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME"; \
  apt-key list > /dev/null

ENV MYSQL_MAJOR 5.7
ENV MYSQL_VERSION 5.7.28-1debian9

RUN echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list

RUN { \
    echo mysql-community-server mysql-community-server/data-dir select ''; \
    echo mysql-community-server mysql-community-server/root-pass password ''; \
    echo mysql-community-server mysql-community-server/re-root-pass password ''; \
    echo mysql-community-server mysql-community-server/remove-test-db select false; \
   } | debconf-set-selections \
  && apt-get update && apt-get install -y mysql-server="${MYSQL_VERSION}" && rm -rf /var/lib/apt/lists/* \
  && rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql \
  && chown -R mysql:mysql /var/lib/mysql \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
  # && chmod 777 /var/lib/mysql/mysqld \
# comment out a few problematic configuration values
  && find /etc/mysql/ -name '*.cnf' -print0 \
    | xargs -0 grep -lZE '^(bind-address|log|pid-file|socket)' \
    | xargs -rt -0 sed -Ei 's/^(bind-address|log|pid-file|socket)/#&/' \
# don't reverse lookup hostnames, they are usually another container
  && echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf \
  && echo 'pid-file=/var/lib/mysql/mysqld.pid\nsocket=/var/lib/mysql/mysqld.sock' >> /etc/mysql/mysql.conf.d/mysqld.cnf \
  && echo 'socket=/var/lib/mysql/mysqld.sock' >> /etc/mysql/conf.d/mysql.cnf

# RUN set -ex \
#       && mysqld --user=mysql --initialize-insecure
# RUN set -ex \
#       && mysqld --user=mysql --skip-networking --socket=/var/lib/mysql/mysqld.sock
