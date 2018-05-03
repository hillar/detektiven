#!/bin/bash
# prepare IPA
# add hostenroll
#
# bash -x $0 192.168.122.254 dummy.key edt0P5fTujPZehgqw e40P5fTujPZehgjB
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

ipa_user_exists() {
  [ -z $1 ] || IPAIP=$1
  [ -z $IPAIP ] && die "no ip for IPA ${IPAIP}"
  [ -z $2 ] || KEYFILE=$2
  [ -z $KEYFILE ] && die "no key file for ${IPAIP}"
  [ -z $3 ] || USER=$3
  [ -z $USER ] && die "no user for ${IPAIP}"
  [ -z $4 ] || MASTERPASSWORD=$4
  [ -z $MASTERPASSWORD ] && die "no password for ipa ${IPAIP}"
  [ -z $5 ] || USERNAME=$5
  [ -z $USERNAME ] && die "no username to search"
  exists=$(ssh -oStrictHostKeyChecking=no -i ${KEYFILE} root@${IPAIP} "LC_ALL="";echo "${P}" | kinit admin > /dev/null; ipa user-find ${USERNAME} > /dev/null; echo \$?")
  [ $exists -eq 0 ] && log "user ${USERNAME} exists"
  [ $exists -eq 0 ] || log "user ${USERNAME} not exists"
  [ $exists -eq 0 ] || return 1
}

ipa_preparedefaults() {
  READONLY='onlyread'
  [ -z $7 ] || READONLY=$7
  HOSTENROLL='hostenroll'
  [ -z $6 ] || HOSTENROLL=$6
  SYSADMIN='sysadmin'
  [ -z $5 ] || SYSADMIN=$5
  [ -z $1 ] || IPAIP=$1
  [ -z $IPAIP ] && die "no ip for IPA ${IPAIP}"
  [ -z $2 ] || KEYFILE=$2
  [ -z $KEYFILE ] && die "no key file for ${IPAIP}"
  [ -z $3 ] || USER=$3
  [ -z $USER ] && die "no user for ${IPAIP}"
  [ -z $4 ] || MASTERPASSWORD=$4
  [ -z $MASTERPASSWORD ] && die "no password for ipa ${IPAIP}"
  [ -f $HOSTENROLL.passwd ] && HOSTENROLLPASSWORD=$(cat $HOSTENROLL.passwd)
  [ -z $HOSTENROLLPASSWORD ] && HOSTENROLLPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  [ -z $HOSTENROLLPASSWORD ] && die "can not create password for ${$HOSTENROLL}"
  echo $HOSTENROLLPASSWORD > $HOSTENROLL.passwd
  [ -f $SYSADMIN.passwd ] && SYSADMINPASSWORD=$(cat $SYSADMIN.passwd)
  [ -z $SYSADMINPASSWORD ] && SYSADMINPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  [ -z $SYSADMINPASSWORD ] && die "can not create password for $SYSADMIN"
  echo $SYSADMINPASSWORD > $SYSADMIN.passwd
  [ -f $READONLY.passwd ] && READONLYPASSWORD=$(cat $READONLY.passwd)
  [ -z $READONLYPASSWORD ] && READONLYPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  [ -z $READONLYPASSWORD ] && die "can not create password for $READONLY"
  echo $READONLYPASSWORD > $READONLY.passwd


  read -r -d '' CMD <<EOF
  LC_ALL="";
  echo -en "${MASTERPASSWORD}" | kinit admin;
  # delete ssh & x509 cert self service;
  ipa selfservice-del "Users can manage their own SSH public keys";
  ipa selfservice-del "Users can manage their own X.509 certificates";
  # create default host enrollment;
  ipa hostgroup-add default --desc "Default hostgroup for IPA clients";
  ipa automember-add --type=hostgroup default --desc="Default hostgroup for new client enrollments";
  ipa automember-add-condition --type=hostgroup default --inclusive-regex=.* --key=fqdn;
  ipa role-add HostEnrollment;
  ipa role-add-privilege HostEnrollment --privileges='Host Enrollment';
  ipa role-add-privilege HostEnrollment --privileges='Host Administrators';
  ipa user-add ${HOSTENROLL} --first=host --last=enroll  --homedir=/dev/null --shell=/sbin/nologin;
  echo -en "${HOSTENROLLPASSWORD}\n${HOSTENROLLPASSWORD}\n" |ipa passwd ${HOSTENROLL};
  ipa role-add-member HostEnrollment --users=${HOSTENROLL};
  echo -en "${HOSTENROLLPASSWORD}\n${HOSTENROLLPASSWORD}\n${HOSTENROLLPASSWORD}\n" | kinit ${HOSTENROLL};
  klist;
  echo -en "${MASTERPASSWORD}" | kinit admin;
  klist;
  #sudo rule for admins;
  ipa sudorule-add admin_all --desc="Rule for admins";
  ipa sudorule-add-user admin_all --groups=admins;
  ipa sudorule-add-host admin_all --hostgroups=default;
  ipa sudorule-mod admin_all --cmdcat=all;
  ipa sudorule-add-option admin_all --sudooption='!authenticate';
  ipa sudorule-show admin_all;
  # add sysadmin user;
  ipa user-add ${SYSADMIN} --first=sys --last=admin;
  ipa group-add-member admins --users=${SYSADMIN};
  echo -en "$SYSADMINPASSWORD\n$SYSADMINPASSWORD\n" |ipa passwd ${SYSADMIN};
  echo -en "$SYSADMINPASSWORD\n$SYSADMINPASSWORD\n$SYSADMINPASSWORD\n" |kinit ${SYSADMIN};
  klist;
  # add readonly user;
  echo -en "${MASTERPASSWORD}" | kinit admin;
  klist;
  ipa permission-add ReadOnlyLDAP  --filter='(!(cn=admins))'  --right=read --right=search --right=compare
  ipa privilege-add ReadOnlyLDAP
  ipa privilege-add-permission ReadOnlyLDAP --permissions=ReadOnlyLDAP
  ipa role-add ReadOnlyLDAP
  ipa role-add-privilege ReadOnlyLDAP --privileges=ReadOnlyLDAP
  ipa user-add ${READONLY} --first=read --last=only;
  echo -en "$READONLYPASSWORD\n$READONLYPASSWORD\n" |ipa passwd ${READONLY};
  ipa role-add-member ReadOnlyLDAP --users=${READONLY}
  echo -en "$READONLYPASSWORD\n$READONLYPASSWORD\n$READONLYPASSWORD\n" |kinit ${READONLY};
  klist;



EOF
  ssh -oStrictHostKeyChecking=no -i ${KEYFILE} root@${IPAIP} "$CMD"
}
