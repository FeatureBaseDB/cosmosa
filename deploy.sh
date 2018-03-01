#!/bin/bash -x

# This script helps reset the entire Cosmosa demo - it clears all data and
# restarts all running processes. It is not well tested, but hopefully provides
# a good starting point.

# This script assumes that $GOPATH on $COSMOSA_HOST is ~/go

# Set COSMOSA_HOST, COSMOSA_BIND, COSMOSA_PROXY, and the CosmosDB variables in your environment. E.G.
# export COSMOSA_HOST="cosmos.pilosa.com"
# export COSMOSA_BIND=8000
# export COSMOSA_PROXY=13131
# export COSMOSA_ACCOUNT="mydbacc"
# export COSMOSA_GROUP="pilosla"
# export COSMOSA_DB="mynewdb"
# export COSMOSA_DB_PASSWORD="klsedf8923j4hl34689cfg984b2jk4h58dgt6yo3lkj67h07sdfbkjeywe=="

# Install the "az" CLI tool
# Run "az login"
# Make sure you have passwordless ssh set up to $COSMOSA_HOST

# kill pdk and pilosa remotely, wipe pilosa data.
ssh $COSMOSA_HOST 'killall pilosa; rm -rf ./pilosadata1; killall pdk'

# rebuild and copy pdk binary to agent
# uncomment the next 3 lines if you're making local changes to the pdk and want to use them.
# export GOOS=linux
# go install ./cmd/pdk
# scp $GOPATH/bin/linux_amd64/pdk $COSMOSA_HOST:

# delete cosmosdb collection for fresh data
az cosmosdb collection delete -c people -d $COSMOSA_DB -n $COSMOSA_ACCOUNT -g $COSMOSA_GROUP

# restart pilosa
ssh $COSMOSA_HOST 'nohup ./go/bin/pilosa server --data-dir=./pilosadata1 &> pilosa.log &'

# restart pdk
ssh $COSMOSA_HOST "nohup ./go/bin/pdk http --subjecter.path=\"id\" --framer.collapse=\"$v\" --framer.ignore=\"$t,_id,_rid,_self,_etag,_attachments,_ts,_lsn\" --batch-size=100000 --bind=$COSMOSA_HOST:$COSMOSA_BIND --proxy=$COSMOSA_HOST:$COSMOSA_PROXY &> pdk.log &"

# re-create "people" collection
cosmosa -just-create

echo "Collection has been deleted and recreated - sleeping for 20 seconds - restart Function App now!"
sleep 20

# Now restart the Function App in the Azure Portal

# start inserting records
cosmosa -insert -num 10000
