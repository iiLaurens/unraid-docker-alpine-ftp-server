#!/bin/sh

#Remove all ftp users
grep 'FTP User' /etc/passwd | cut -d':' -f1 | xargs -r -n1 deluser

#Create users
#USERS='name1|password1|[folder1][|uid1][|gid1] name2|password2|[folder2][|uid2][|gid2]'
#may be:
# user|password foo|bar|/home/foo
#OR
# user|password|/home/user/dir|10000
#OR
# user|password|/home/user/dir|10000|10000
#OR
# user|password||10000|82

#Default user 'ftp' with password 'alpineftp'

if [ -z "$USERS" ]; then
  USERS="alpineftp|alpineftp"
fi

for i in $USERS ; do
  NAME=$(echo $i | cut -d'|' -f1)
  GROUP=$NAME
  PASS=$(echo $i | cut -d'|' -f2)
  FOLDER=$(echo $i | cut -d'|' -f3)
  MAYBE_UID=$(echo $i | cut -d'|' -f4)
  MAYBE_GID=$(echo $i | cut -d'|' -f5)
  UID_=${MAYBE_UID:-$UID}
  GID_=${MAYBE_GID:-$GID}

  if [ -z "$FOLDER" ]; then
    FOLDER="/ftp/$NAME"
  fi

  #Check if the group with the same ID already exists
  GROUP=$(getent group $GID_ | cut -d: -f1)
  if [ ! -z "$GROUP" ]; then
    GROUP_OPT="-G $GROUP"
  elif [ ! -z "$GID_" ]; then
    # Group don't exist but GID supplied
    addgroup -g $GID_ $NAME
    GROUP_OPT="-G $NAME"
  fi

  echo -e "$PASS\n$PASS" | adduser -h $FOLDER -s /sbin/nologin -g "FTP User" $GROUP_OPT $NAME
  
  # Change UID used SED to avoid uid conflict error message
  sed -i -E "s/$NAME:x:[0-9]+:/$NAME:x:$UID_:/g" /etc/passwd
  unset NAME PASS FOLDER GROUP UID_ GID_
done


if [ -z "$MIN_PORT" ]; then
  MIN_PORT=21000
fi

if [ -z "$MAX_PORT" ]; then
  MAX_PORT=21010
fi

if [ ! -z "$ADDRESS" ]; then
  ADDR_OPT="-opasv_address=$ADDRESS"
fi

if [ ! -z "$TLS_CERT" ] || [ ! -z "$TLS_KEY" ]; then
  TLS_OPT="-orsa_cert_file=$TLS_CERT -orsa_private_key_file=$TLS_KEY -ossl_enable=YES -oallow_anon_ssl=NO -oforce_local_data_ssl=YES -oforce_local_logins_ssl=YES -ossl_tlsv1=YES -ossl_sslv2=NO -ossl_sslv3=NO -ossl_ciphers=HIGH"
fi

# Used to run custom commands inside container
if [ ! -z "$1" ]; then
  exec "$@"
else
  vsftpd -opasv_min_port=$MIN_PORT -opasv_max_port=$MAX_PORT $ADDR_OPT $TLS_OPT /etc/vsftpd/vsftpd.conf
  [ -d /var/run/vsftpd ] || mkdir /var/run/vsftpd
  pgrep vsftpd | tail -n 1 > /var/run/vsftpd/vsftpd.pid
  exec pidproxy /var/run/vsftpd/vsftpd.pid true
fi
