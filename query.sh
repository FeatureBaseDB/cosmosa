#!/bin/bash -x

# querying the proxy
curl $COSMOSA_HOST:$COSMOSA_PROXY/index/jsonhttp/query -d'TopN(frame=tiles, n=20)'
curl $COSMOSA_HOST:$COSMOSA_PROXY/index/jsonhttp/query -d'Intersect(Bitmap(frame=tiles, rowID=bx), Bitmap(frame=tiles, rowID=lh), Bitmap(frame=tiles, rowID=e8))'

# querying pilosa directly (may need to be done on localhost)
curl $COSMOSA_HOST:10101/index/jsonhttp/query -d'TopN(frame=tiles, n=20)'
curl $COSMOSA_HOST:10101/index/jsonhttp/query -d'Intersect(Bitmap(frame=tiles, rowID=11931), Bitmap(frame=tiles, rowID=1747), Bitmap(frame=tiles, rowID=5036))'



