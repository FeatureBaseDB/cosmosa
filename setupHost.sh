#!/bin/bash

export AZURE_USERNAME=`whoami`
# export COSMOSA_HOST=52.186.84.133

ssh $AZURE_USERNAME@$COSMOSA_HOST "printf \"export COSMOSA_HOST=$COSMOSA_HOST\nexport COSMOSA_BIND=$COSMOSA_BIND\nexport COSMOSA_PROXY=$COSMOSA_PROXY\nexport COSMOSA_DB_PASSWORD=$COSMOSA_DB_PASSWORD\nexport COSMOSA_DB=$COSMOSA_DB\nexport COSMOSA_ACCOUNT=$COSMOSA_ACCOUNT\" >> .profile"

ssh $AZURE_USERNAME@$COSMOSA_HOST '
wget https://storage.googleapis.com/golang/go1.10.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.10.linux-amd64.tar.gz
sudo chown -R $ME:$ME /usr/local/go
mkdir -p /home/$ME/go/src/github.com/pilosa
mkdir -p /home/$ME/go/bin
GOPATH=/home/$ME/go
export GOPATH
PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
export PATH

export ME=`whoami`
echo "export GOPATH=/home/$ME/go" >> .profile
echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> .profile

curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

sudo apt-get -y install make git
'

