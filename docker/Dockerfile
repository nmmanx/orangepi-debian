FROM debian:10
MAINTAINER Man Nguyen <nmman37@gmail.com>

ARG USERNAME
ARG USERID
ARG GROUPID

RUN groupadd -g $GROUPID $USERNAME
RUN useradd -m -u $USERID -g $GROUPID $USERNAME
RUN echo $USERNAME:root | chpasswd

RUN apt -y update
RUN apt -y install sudo
RUN usermod -aG sudo $USERNAME

ENV HOME=/home/$USERNAME
ENV USER=$USERNAME
ENV DOCKER=1

RUN apt -y update
RUN apt -y install debootstrap xz-utils

RUN echo "#!/bin/bash" > /run/startup.sh
RUN echo "chroot --userspec=$USERNAME:$USERNAME / /bin/bash -i" >> /run/startup.sh
RUN chmod g+x /run/startup.sh

RUN cat /run/startup.sh
ENTRYPOINT ["/run/startup.sh"]
