#!/bin/bash
#
# install freeipa
#

echo "$(date) starting $0"

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;(";
    exit;
fi

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi
[ -d "/vagrant" ] || mkdir /vagrant


_PASSWORD_='password'
_UID_='username'


IP='127.0.0.1'
[ -z $1 ] || IP=$1
HOSTNAME='ipa'
[ -z $2 ] || HOSTNAME=$2
DOMAIN='example.org'
[ -z $3 ] || DOMAIN=$3


echo "127.0.0.1 localhost" > /etc/hosts
echo "$IP ${HOSTNAME}.${DOMAIN} ${HOSTNAME}" >> /etc/hosts

export DEBIAN_FRONTEND=noninteractive

# http://gatwards.org/techblog/ipa-server-installation
apt-get update >> /vagrant/provision.log 2>&1
apt-get -y install freeipa-server >> /vagrant/provision.log 2>&1


DirectoryManagerpassword=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)
IPAadminpassword="$DirectoryManagerpassword"

echo -en "\n\n\n\n$DirectoryManagerpassword\n$DirectoryManagerpassword\n$IPAadminpassword\n$IPAadminpassword\nyes\n" | ipa-server-install
echo -en "$IPAadminpassword" | kinit admin

# delete ssh & x509 cert self service
ipa selfservice-del "Users can manage their own SSH public keys"
ipa selfservice-del "Users can manage their own X.509 certificates"

#We create a rule that adds any host having a FQDN of * (ie every new client enrollment) to the Default Hostgroup.
ipa hostgroup-add default --desc "Default hostgroup for IPA clients"
ipa automember-add --type=hostgroup default --desc="Default hostgroup for new client enrollments"
ipa automember-add-condition --type=hostgroup default --inclusive-regex=.* --key=fqdn
#sudo rule for default
ipa sudorule-add admin_all --desc="Rule for admins"
ipa sudorule-add-user admin_all --groups=admins
ipa sudorule-add-host admin_all --hostgroups=default
ipa sudorule-mod admin_all --cmdcat=all
ipa sudorule-add-option admin_all --sudooption='!authenticate'
ipa sudorule-show admin_all

# AFAIK there is 'Host Enrollment' privilege created during IPA server installation.
# You need to create new role and add this privilege to the newly created role.
ipa role-add HostEnrollment
ipa role-add-privilege HostEnrollment --privileges='Host Enrollment'
#Creating hosts is a separate permission ('System: Add Hosts') granted to a
# separate privilege, 'Host Administrators'.
ipa role-add-privilege HostEnrollment --privileges='Host Administrators'
# The role can then be assigned to any user or group.
ipa user-add hostenroll --first=host --last=enroll  --homedir=/dev/null --shell=/sbin/nologin
echo -en "$_PASSWORD_\n$_PASSWORD_\n" |ipa passwd hostenroll
ipa role-add-member HostEnrollment --users=hostenroll
# do the first login, so hosts can use hostenroll
echo -en "$_PASSWORD_\n$_PASSWORD_\n\$_PASSWORD_\n" | kinit hostenroll
klist
echo -en "$IPAadminpassword" | kinit admin
klist
# create read only bind user to search for user
#A. First, make that dedicated ldap auth user in FreeIPA, for example, username: readonly with a good password.
ipa user-add $_UID_ --first=web --last=eid  --homedir=/dev/null --shell=/sbin/nologin
echo -en "$_PASSWORD_\n$_PASSWORD_\n" |ipa passwd $_UID_
#B. Next, go to IPA Server > Role Based Access Control > Permission
#C. There, create a new Permission called Read Only LDAP Auth and select Granted rights: [x] read [x] search [x] compare
ipa permission-add ReadOnlyLDAP  --filter='(!(cn=admins))'  --right=read --right=search --right=compare
#D. Next, create a Privilege called Read Only LDAP Auth, and add the Permission just created.
ipa privilege-add ReadOnlyLDAP
ipa privilege-add-permission ReadOnlyLDAP --permissions=ReadOnlyLDAP
#E. Finally, create a Role Read Only LDAP Auth, and add the Privilege Read Only LDAP Auth.
ipa role-add ReadOnlyLDAP
ipa role-add-privilege ReadOnlyLDAP --privileges=ReadOnlyLDAP
#F. And lastly, add the user readonly to that Role.
ipa role-add-member ReadOnlyLDAP --users=$_UID_

ipa role-show ReadOnlyLDAP
ipa user-find $_UID_
#ldapsearch -x -D "uid=$_UID_,cn=users,cn=accounts,dc=example,dc=org" -w $_PASSWORD_ -h 192.168.10.2 -b "cn=accounts,dc=example,dc=org" -s sub 'uid=$_UID_'

ipa group-add osse
ipa group-add-member osse --users=$_UID_
ipa group-add hardCodedDefault
ipa group-add-member hardCodedDefault --users=$_UID_
ipa group-add hardCodedDefaultElastic
ipa group-add-member hardCodedDefaultElastic --users=$_UID_



#create fixture user
ipa user-add hillar --first=HILLAR --last=AARELAID --employeenumber=36712316013 --email=hillar.aarelaid@eesti.ee --certificate=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;
ipa user-mod hillar --addattr=mail=hillar.aarelaid@gmail.com;
ipa user-mod hillar --sshpubkey=AAAAB3NzaC1yc2EAAAADAQABAAABAQCZoBOnNscP+wMaErl/lJckLqAb3nA+osjxrYYaKbyIcuq08WEBjsn1Tm7QZyHYhjhIIm14YUsA0KOJtgrH4diCwmg6I8+wdlK6Bf9vE4VPz3DrQT9wFRR0Dyo6jXexipkCZqtCRzW1EFRi/idY/EmAn/KrC3zrIiwQPQc9GuYIqcq1luLAvdukJea8eufx/wOzL9EGADSV9ILboaQP1Xm39LRug5mFsG8JX1uUU0K7z7usIuxPpfmmFUQimIEbGF6NzbQ5AKbkdKazO1HLskHV3HvqCj3bos0uCtMWrKcd+AC3XEQ0vNNswh1mrs3srnfpweJpW+P1daqAXRYwPJ4h,AAAAB3NzaC1yc2EAAAADAQABAAABAQCVGogSAzeTTXoARqvY/yvC+rtD3pCjBdeqOtfkESv4j3RnSZMmIXC7MW9tqf7FBgJK5je9zlyhhtMGy/qhAOmsm4SmyeQkZG6jz6xXrZ8HC+jWgnM5cYaKqFR1QyXW9M2pHwZgcU9gXA79Qo6+b3PO7DduqXM/foS7xHETvzr6PHj5wdP7erzNiBRQhROc2LJKA3lnqrB/XZltIC89DAT0+KelWnaM46W+Ok6DhqoQ/yEabeiU3yfjA3wpScV60e91wdJLVrzHqI3qZCL8GTCPs/viiE2VTYNsM/1btsnv06vli7lJwfmtytIuye/3Z0VzDB0OckXPMVI//GmnKz47;
ipa group-add-member osse --users=hillar

ipa user-add hillar.aarelaid --first=HILLAR --last=AARELAID --employeenumber=36712316013 --email=hillar.aarelaid@eesti.ee --sshpubkey="AAAAB3NzaC1yc2EAAAADAQABAAABAQCXUshcGwaGvnKTsm6NdNJt6C0+NzaJtXeNbtTB43ohgbkBawL8c9uLMxDAtS4HqLYZy3QlcSpAHlGRDvJqnOLUSRduOG3efq+q0yTI7QWzFyo+qpVVH9jiwSqwYdvbvKZet9NUZ1ePTHNpRkthsxp1mvI5+AMXAuYhzNjoNw4F9FyEd8W/NMoBJYpBIxll7k+yCA7Rv8eCb8CTYUJBOFxhn2sB9EVyq0ix2WrUZmByAb4MZClrTxRD3hifSSZB9lW2+8QLqILt0AkTYSdYMAWHJZWvA/2O/quMw9SFHW/aDHLEuqCMFW7yfKbbrUOoePUmcgBdRLeFWUqlFCL1wAO5" --sshpubkey="AAAAB3NzaC1yc2EAAAADAQABAAABAQCaLd8tE8WQpL6uN13DnrNpE6K6rmodtsbmaj0wclwxgpiy9gsCxSUnwhsaWUr/7EH2SjMdm0YVNQWV4xiBtbdvUpH22/XNmbuIrINwA8K8WwYTyp8IyNeBOziaFcbT5jDc4NZA5bb2FxDdq/TgEF8R4BWxrAXknrCsqUmsbaYB/5WqVCdYmBFcP+LJbk+2jTmWgxK7ZawOxQA4JHswoBdmW4lWE5NCCFNFY8tkHO6/qq4ZVTn9yP64kAIgaMIrM2qvHUtQXGV4t7BPrKdQ6gkKbz5s7nn9gDNA0i86Ld7R5hK+ILKtTg2bPQEe0Nh6DC3XHVU2XyrEd7AacYJ7z2rz" --certificate="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" --certificate="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"
ipa group-add-member osse --users=hillar.aarelaid





# save temporary password
echo "$IPAadminpassword" > /root/ipapass.txt
echo "admin password is $IPAadminpassword"
echo "$(date) bind ip $IP"
