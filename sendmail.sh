RELAY_HOST='smtp://mail.yourDomain.az'
RELAY_USER='yourUser@yourDomain.az:yourPass'
FROM='yourUser@yourDomain.az'
RCPT='rcptUser@rcptDomain.az'

curl -v \
 --user $RELAY_USER \
 --mail-from $FROM \
 --mail-rcpt $RCPT \
 --url $RELAY_HOST <<EOF
From: "OneWayMail" <$FROM>
To: "You" <$RCPT>
Subject: Test mail
Hello from $(hostname)
EOF
