FROM amazonlinux:latest

# $NGINX_VERSION and $NGINX_VERSION_YUM need to be specified as part of the run
ENV RHELVER=7
ENV basearch=x86_64
ENV BASE_FOLDER=/nginx-build
ENV OUTPUT_FOLDER=/output

# Copy the build scrip into the image
COPY amazon-linux-docker-nginx.sh $BASE_FOLDER/amazon-linux-docker-nginx.sh

RUN yum install -y yum-utils less which tar gcc gcc-c++ make pcre pcre-devel zlib zlib-devel wget gnupg openssl openssl-devel redhat-rpm-config libxslt-devel gd-devel perl-ExtUtils-Embed google-perftools-devel && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum-config-manager --enable epel && \
    yum install -y nginx && \
    yum makecache


WORKDIR $BASE_FOLDER
ENTRYPOINT ["./amazon-linux-docker-nginx.sh"]