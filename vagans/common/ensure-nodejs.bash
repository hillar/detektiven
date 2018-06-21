#!/usr/bin/env bash
#
# install java
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

nodejs --version > /dev/null 2&>1
if [ $? -eq 0 ]; then
  log "nodejs exists $(nodejs --version) "
else
  log "installing nodejs"
  apt --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash - >>  /tmp/provision.log 2>&1
    apt-get install -y nodejs npm >>  /tmp/provision.log 2>&1
  fi
  dnf --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
     curl --silent --location https://rpm.nodesource.com/setup_9.x | sudo bash - >>  /tmp/provision.log 2>&1
     yum -y install nodejs >>  /tmp/provision.log 2>&1
     ln -s /usr/bin/node /usr/bin/nodejs
  fi
  nodejs --version > /dev/null 2&>1
  [ $? -eq 0 ] || die 'failed to install nodejs'
  npm --version > /dev/null 2&>1
  [ $? -eq 0 ] || die 'failed to install npm'
  log "installed nodejs $(nodejs --version) $(npm --version)"
fi
