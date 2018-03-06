# OSSE

search in both SOLR(s) and ElasticSearch(s)




filesonthedisk <-> fileserver <-> osse <-> browser

----
title Upload Sequence

browser->osse: upload
osse->index:?exists
alt no
index->osse: no
osse->fileserver:upload
fileserver->tika:raw
tika->fileserver:meta
fileserver->index:meta
end

----

graph osse {

  {rank=same osse freeipa}
  browser -- osse -- freeipa
  subgraph cluster_i {
  label = "index servers"
  i1 [label="solr"]
  i2 [label="elastic"]
  i3 [label="elastic"]
  }
  subgraph cluster_f {
  label = "file servers with ETL"
  f1 [label="files+etl"]
  f2 [label="files"]
  f3 [label="files"]
  f4 [label="files"]
  }

  osse -- {i1 i2 i3}
  osse -- {f1 f2 f3 f4}
  {f1 f2 f3 f4} -- tika [style="dotted"]
  {i1} --  {f1 f2 } [style="dotted"]
  {i3} --  {f3 } [style="dotted"]
  {i2} --  {f4 } [style="dotted"]

}
