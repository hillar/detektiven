#!/bin/bash
# script to send  mail with netcat.
# expects the following arguments:
# 1. mail to (e.g. to@example.com)
# 2. Subject
# 3. Message

#change
SERVER="smtp.local"
PORT="25"
FROM="noreplay@oss-mini"
# for mail_input function
to=$1
subj=$2
msg=$3

# error handling
function err_exit { echo -e 1>&2 ; exit 1; }
log() { echo "$(date) $0: $*"; }

# check if proper arguments are supplied
if [ $# -ne 3 ]; then
  echo -e "\n Usage error!"
  echo " This script requires arguments:"
  echo " 1. to"
  echo " 2. subject"
  echo " 3. message"
  exit 1
fi

# create message
function mail_input {
  log " sending mail $SERVER $PORT $FROM $to $subj"
  echo "ehlo $SERVER"
  echo "MAIL FROM: <$FROM>"
  echo "RCPT TO: <$to>"
  echo "DATA"
  echo "From: <$FROM>"
  echo "To: <$to>"
  echo "Subject: $subj"
  echo "$msg"
  echo "."
  echo "quit"
}

# send
mail_input | nc $SERVER $PORT || err_exit
