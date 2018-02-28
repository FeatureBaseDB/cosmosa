#!/bin/bash

echo "Top 20 tiles"
time curl $COSMOSA_HOST:$COSMOSA_PROXY/index/jsonhttp/query -d'TopN(frame=tiles, n=20)'

echo "Intersect 3"
time curl $COSMOSA_HOST:$COSMOSA_PROXY/index/jsonhttp/query -d'Intersect(Bitmap(frame=tiles, rowID=bx), Bitmap(frame=tiles, rowID=lh), Bitmap(frame=tiles, rowID=e8))'


for tile in p1 bx jt wy e8; do
    echo -n $tile " "
    time curl $COSMOSA_HOST:$COSMOSA_PROXY/index/jsonhttp/query -d"Count(Bitmap(frame=tiles, rowID=$tile))"
done
