#!/bin/bash

INPUT=source.txt
OUTPUT=output.json
LINE_CURRENT=0
LINE_TOTAL=$(cat $INPUT | wc -l)

exec > $OUTPUT
echo "{
        \"data\":[
"
while IFS=" " read -r F1 F2 F3
do
        LINE_CURRENT=$(($LINE_CURRENT + 1))
        if [ $LINE_CURRENT -lt $LINE_TOTAL ] ; then
                echo -e "       { \"{#HOSTNAME}\":\""$F1"\", \"{#IP}\":\""$F2"\", \"{#PORT}\":\""$F3"\" },"
        else
                echo -e "       { \"{#HOSTNAME}\":\""$F1"\", \"{#IP}\":\""$F2"\", \"{#PORT}\":\""$F3"\" }"
        fi
done < $INPUT
echo "
        ]
}"

# Example: source.txt structure
# HOST1 10.10.10.10 443
# HOST2 10.10.10.11 80
# HOST3 10.10.10.12 8888
