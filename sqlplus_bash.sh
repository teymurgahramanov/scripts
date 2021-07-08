#!/bin/bash

# Download Oracle SQLPlus

export ORACLE_HOME=# Path to Oracle SQLPlus directory
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$PATH:$ORACLE_HOME/bin

export USER=# Username
export PASSWORD=# Password
export HOST=# Oracle database server
export PORT=# Port
export SERVICE=# Service name

sqlplus -s /nolog <<EOF
CONNECT $USER/$PASSWORD@$HOST:$PORT/$SERVICE;
### PLACE FOR YOUR SQL CODE; ###
EOF
