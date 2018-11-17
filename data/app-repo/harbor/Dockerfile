FROM centos

RUN yum update -y

RUN yum-config-manager \
    --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo
RUN curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

