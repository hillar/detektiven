#!/bin/bash
# prepare IPA
# add hostenroll
#
# bash -x $0 192.168.122.254 dummy.key edt0P5fTujPZehgqw e40P5fTujPZehgjB
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

hostenroll() {
  HOSTENROLL='hostenroll2'

  [ -z $1 ] || IPAIP=$1
  [ -z $IPAIP ] && die "no ip for IPA ${IPAIP}"
  [ -z $2 ] || KEYFILE=$2
  [ -z $KEYFILE ] && die "no key file for ${IPAIP}"
  [ -z $3 ] || MASTERPASSWORD=$3
  [ -z $MASTERPASSWORD ] && die "no password for ipa ${IPAIP}"
  [ -z $4 ] || HOSTENROLLPASSWORD=$4
  [ -z $HOSTENROLLPASSWORD ] && HOSTENROLLPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  [ -z $HOSTENROLLPASSWORD ] && die "can not create password for hostenroll"

  echo $HOSTENROLLPASSWORD > $HOSTENROLL.passwd


  read -r -d '' CMD <<EOF
  echo -en "${MASTERPASSWORD}" | kinit admin;
  #ipa hostgroup-add default --desc "Default hostgroup for IPA clients";
  #ipa automember-add --type=hostgroup default --desc="Default hostgroup for new client enrollments";
  #ipa automember-add-condition --type=hostgroup default --inclusive-regex=.* --key=fqdn;
  #ipa role-add HostEnrollment;
  #ipa role-add-privilege HostEnrollment --privileges='Host Enrollment';
  #ipa role-add-privilege HostEnrollment --privileges='Host Administrators';
  ipa user-add ${HOSTENROLL} --first=host --last=enroll  --homedir=/dev/null --shell=/sbin/nologin;
  echo -en "${HOSTENROLLPASSWORD}\n${HOSTENROLLPASSWORD}\n" |ipa passwd ${HOSTENROLL};
  ipa role-add-member HostEnrollment --users=${HOSTENROLL};
  echo -en "${HOSTENROLLPASSWORD}\n${HOSTENROLLPASSWORD}\n${HOSTENROLLPASSWORD}\n" | kinit ${HOSTENROLL};
  klist
  EOF
  ssh -oStrictHostKeyChecking=no -i ${KEYFILE} root@${IPAIP} "$CMD"
}
