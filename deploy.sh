#!/bin/bash -x

# This script helps reset the entire Cosmosa demo - it clears all data and
# restarts all running processes. It is not well tested, but hopefully provides
# a good starting point.

# This script assumes that $GOPATH on $HOST is ~/go

# Set HOST, BIND, PROXY, and the CosmosDB variables in your environment. E.G.
# export HOST="cosmos.pilosa.com"
# export BIND=8000
# export PROXY=13131
# export AZURE_COSMOS_ACCOUNT="mydbacc"
# export AZURE_RESOURCE_GROUP="pilosla"
# export AZURE_DATABASE="mynewdb"
# export AZURE_DATABASE_PASSWORD="klsedf8923j4hl34689cfg984b2jk4h58dgt6yo3lkj67h07sdfbkjeywe=="

# Install the "az" CLI tool
# Run "az login"
# Make sure you have passwordless ssh set up to $HOST

# kill pdk and pilosa remotely, wipe pilosa data.
ssh $HOST 'killall pilosa; rm -rf ./pilosadata1; killall pdk'

# rebuild and copy pdk binary to agent
# uncomment the next 3 lines if you're making local changes to the pdk and want to use them.
# export GOOS=linux
# go install ./cmd/pdk
# scp $GOPATH/bin/linux_amd64/pdk $HOST:

# delete cosmosdb collection for fresh data
az cosmosdb collection delete -c people -d $AZURE_DATABASE -n $AZURE_COSMOS_ACCOUNT -g $AZURE_RESOURCE_GROUP

# restart pilosa
ssh $HOST 'nohup ./go/bin/pilosa server --data-dir=./pilosadata1 &> pilosa.log &'

# restart pdk
ssh $HOST "nohup ./go/bin/pdk http --subjecter.path=\"id\" --framer.collapse=\"$v\" --framer.ignore=\"$t,_id,_rid,_self,_etag,_attachments,_ts,_lsn\" --batch-size=100000 --bind=$HOST:$BIND --proxy=$HOST:$PROXY &> pdk.log &"

# re-create "people" collection
cosmosla -just-create

echo "Collection has been deleted and recreated - sleeping for 20 seconds - restart Function App now!"
sleep 20

# Now restart the Function App in the Azure Portal

# start inserting records
cosmosla -insert -num 10000
