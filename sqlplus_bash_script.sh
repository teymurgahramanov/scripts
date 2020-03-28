#!/bin/bash

export ORACLE_HOME=# Path to sqplus directory
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$PATH:$ORACLE_HOME/bin

USER=# Username
PASSWORD=# Password
HOST=# Oracle database server
PORT=# Port
SERVICE=# Service name

sqlplus -s /nolog <<EOF
CONNECT $USER/$PASSWORD@$HOST:$PORT/$SERVICE;
### PLACE FOR YOUR SQL CODE; ###
EOF
