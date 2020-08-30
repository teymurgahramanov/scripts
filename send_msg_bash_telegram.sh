#!/bin/bash

TOKEN='10293u:24102jkn34-234201u2401u23-4912lsWEMRO2'
CHAT="$1"
SUBJECT="$2"
MESSAGE="$3"

/usr/bin/curl -s \
  --header 'Content-Type: application/json' \
  --request 'POST' \
  --data "{\"chat_id\":\"${CHAT}\",\"text\":\"${SUBJECT}\n${MESSAGE}\"}" "https://api.telegram.org/bot${TOKEN}/sendMessage"
