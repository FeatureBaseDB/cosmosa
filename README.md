This repository contains instructions and resources for running Pilosa in
conjunction with Microsoft's Azure CosmosDB. We describe a demo which includes:

- generating data and writing it to CosmosDB.
- creating a Function App to process the CosmosDB change feed
- running `pdk http` from the [PDK](https://github.com/pilosa/pdk) to receive the change feed and index it in Pilosa.
- running [Pilosa](https://github.com/pilosa/pilosa)
- querying Pilosa and CosmosDB and comparing the results!

### Before you start
Make sure you have an Azure account and can log in to the Azure web portal. Then, [install the azure CLI tool.](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

### Setting up CosmosDB
Create an Azure CosmosDB database, and have your CosmosDB account name, resource
group, database name, and password at the ready.

```bash
export COSMOSA_GROUP=cosmosaRG
export COSMOSA_LOCATION=eastus
export COSMOSA_ACCOUNT=accountcomosa
export COSMOSA_DB=cosmosa
az login
# you'll have to enter a code on a web page
az group create --name $COSMOSA_GROUP --location $COSMOSA_LOCATION
az cosmosdb create -g $COSMOSA_GROUP -n $COSMOSA_ACCOUNT
az cosmosdb database create -g $COSMOSA_GROUP -n $COSMOSA_ACCOUNT -d $COSMOSA_DB

```

You'll also need a server or container with a public IP or DNS address on which
you can run Pilosa and the PDK on. A few GB of memory and 2-4 CPU cores should
be sufficient, and use any popular Linux distribution as the OS.

Make sure you have at least two open TCP ports on this server, and have its
hostname or IP address handy. I'll refer to these throughout this document as:

- `$BIND` (first open port)
- `$PROXY` (second open port)
- `$HOST` (hostname or IP address)

[Install Go](https://golang.org/doc/install) on your server. Make sure that your
GOPATH is set up as instructed, and that `$GOPATH/bin` is on your PATH.

Ensure that `git` and `make` are installed on your server.

### Setting up cosmosa to write to CosmosDB
If you wish to directly replicate our experiment, please use the rather hastily
written [Cosmosa](https://github.com/pilosa/cosmosa) which is in this repository.

That said, if you have a different data set which you'd like to try, or you just
want to make tweaks to the existing code, we'd highly encourage you to do so.
Please report any issues you encounter here, or to the approriate repository if
it's clear where the problem is occurring.

You can run this from the server you set up, or somewhere else that you have Go
installed. First set up these environment variables using the appropriate values
from the CosmosDB you set up:

```bash
export COMSOSA_ACCOUNT="mydbacc"
export COSMOSA_DB="mynewdb"
export COSMOSA_DB_PASSWORD="Ldlkfwoiu384b23ljh4f089s89ueorihj3h4jkhs09023845ht9s8duf023hjsv084ytblpt28234=="
```

Now, install and run `cosmosa` to set up the appropriate collection in CosmosDB.

```bash
go get github.com/pilosa/cosmosa
cd $GOPATH/src/github.com/pilosa/cosmosa
go install
cosmosa -just-create
```

The `-just-create` flag tells `cosmosa` not to write any data or make any
queries, but just create a collection in your CosmosDB database. We'll set up
the rest of our infrastructure and then come back to this.

### Start Pilosa

You may want to do this in screen or tmux so that you can easily come back to it
if your ssh session dies.

```bash
git clone https://github.com/pilosa/pilosa.git $GOPATH/src/github.com/pilosa/pilosa
cd $GOPATH/src/github.com/pilosa/pilosa
git checkout origin/cluster-resize
make install
pilosa server
```

Pilosa should now be running and listening on `localhost:10101`. 

### Install and start PDK

Again, a terminal multiplexer such as screen or tmux could be helpful here.

```bash
git clone https://github.com/pilosa/pdk.git $GOPATH/src/github.com/pilosa/pdk
cd $GOPATH/src/github.com/pilosa/pdk
git checkout origin/generic-improvements
make install
pdk http --subjecter.path="id" --framer.collapse='$v' --framer.ignore='$t,_id,_rid,_self,_etag,_attachments,_ts,_lsn' --batch-size=50000 --bind="$HOST:$BIND" --proxy="$HOST:$PROXY"
```

The various arguments to `pdk http` are described by `pdk http -h`. The PDK should now be listening for HTTP POST requests on `$HOST:$BIND` and listening for queries to proxy to Pilosa on `$HOST:$PROXY` (more on this later).


### Create a Function App to process the CosmosDB Change feed
1. `In the Azure portal, click on "+ Create a Resource".
2. Select "Compute" on the left.
3. Select "Function App" on the right.
4. Enter a name and the resource group of your CosmosDB database.
5. Switch the OS to Linux.
6. I created a service plan in the same region as my CosmosDB... not sure if necessary.
7. Select "pin to dashboard" for convenience, and then click "create".
8. Click your Function App once it's done creating.
9. Hit the "+" next to "Functions" and find "CosmosDB trigger"
10. Select C# as the language.
11. Set up the account connection, and use the collection name "people".
12. Enter your database name in the appropriate field and make sure that "create
    lease collection" is checked - the click "Create"!
13. Paste the following C# code into the editor (remember to swap $HOST and $BIND), then save and run!


```C#
#r "Microsoft.Azure.Documents.Client"
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using Microsoft.Azure.Documents;

public static void Run(IReadOnlyList<Document> documents, TraceWriter log) {
   var url = "$HOST:$BIND";
   if (documents != null && documents.Count > 0) {
       log.Verbose("Documents modified " + documents.Count);
       log.Verbose("First document Id " + documents[0].Id);
       using (var client = new HttpClient()) {
           for(int n=0; n < documents.Count; n++) {
               log.Verbose(documents[n].ToString());
               var content = new StringContent(documents[n].ToString(), Encoding.UTF8, "application/json");
               var result = client.PostAsync(url, content).Result;
           }
       }
   }
}
```


### Writing Data!
Go back to wherever you installed `cosmosa` earlier on, now we can start writing data.

```bash
cosmosa -insert -num 10000
```

This will probably take around 20 minutes. If all is going well, you should
start to see Pilosa logging about imports and snapshotting. You can also view
the logs for your function app, and explore the data going into CosmosDB through
the Azure portal.

`cosmosa` is inserting documents into CosmosDB which look like:

```json
{
  "alive": "yes",
  "tiles": {
    "p1": true,
    "dkeu": true,
    "szy": true,
    "1z": true,
    ... # several hundred more
  }
}
```

This structure is somewhat arbitrary, and could just as well be:

```json
{
  "alive": "yes",
  "tiles": ["p1", "dkeu", "szy", "1z"...],
}
```

It would end up being indexed the same way in Pilosa, but I didn't know off the
top of my head how to construct the same query in Mongo's query language in that
case. The important part is that each document has several hundred attributes
(tiles) chosen from a set of several million, and a few thousand of them are far
more likely to appear than the rest.


### Querying

`cosmosa` has a `-query` flag which will cause it to run some predefined
queries, and output how long each one took.

```bash
cosmosa -query
```

Pay particular attention to the "intersect 3 count" line.

To run that same query against Pilosa, do

```bash
time curl -XPOST $HOST:$PROXY/index/jsonhttp/query -d'Count(Intersect(Bitmap(frame=tiles, rowID=p1), Bitmap(frame=tiles, rowID=jt), Bitmap(frame=tiles, rowID=wy)))'
```

This is actually querying the proxy server which the PDK is running. It allows you to specify rowIDs as strings (e.g. "p1") rather than the integers which Pilosa knows about.

You can also do a `TopN` query which will show you which tiles appear in the most documents.

```bash
curl -XPOST $HOST:$PROXY/index/jsonhttp/query -d'TopN(frame=tiles, n=10)'
```

And you can even combine the intersection query with the TopN query, which will show you which tiles appear the most in documents which have the specified set of tiles.

```bash
curl -XPOST $HOST:$PROXY/index/jsonhttp/query -d'TopN(Intersect(Bitmap(frame=tiles, rowID=p1), Bitmap(frame=tiles, rowID=jt), Bitmap(frame=tiles, rowID=wy)), frame=tiles, n=10)'
```

Constructing _that_ query in CosmosDB is left as an exercise to the reader :).
