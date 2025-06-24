#/bin/bash

docker network inspect $(docker network ls | grep -F 'bridge' | cut -d' ' -f1) \
    | jq -r '.[] | .Name + " " + .IPAM.Config[0].Subnet' -
