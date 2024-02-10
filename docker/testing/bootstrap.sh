#!/bin/bash

# generate ssh key and store it in keys/ssh_host_rsa_key
keygen=0
if [ ! -f ./multi/keys/ssh_host_rsa_key ]; then
    keygen=1
fi

if [ ! -f ./multi/keys/ssh_host_rsa_key.pub ]; then
    keygen=1
fi

if [ $keygen -eq 1 ]; then
    mkdir -p ./multi/keys
    rm -f ./multi/keys/ssh_host_rsa_key
    rm -f ./multi/keys/ssh_host_rsa_key.pub
    ssh-keygen -q -N "" -t rsa -b 4096 -f ./multi/keys/ssh_host_rsa_key

    # replace the last word in the public key with a fake test@test-client
    sed -i 's/[^ ]*$/test@test-client/' ./multi/keys/ssh_host_rsa_key.pub
fi

SSH_PRIVATEKEY=$(cat ./multi/keys/ssh_host_rsa_key)
SSH_KEY=$(cat ./multi/keys/ssh_host_rsa_key.pub)
SSH_KEY_NAME=test

mkdir -p multi/soft-serve/
cp multi/soft-serve.yml.example multi/soft-serve/config.yaml
sed -i \
    -e "s#SSH-KEY-HERE#${SSH_KEY}#g" \
    multi/soft-serve/config.yaml
