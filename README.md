# detektiven
* see https://github.com/martinpaljak/x509-webauth &amp; https://et.wikipedia.org/wiki/Kalle_Blomkvist

----

![Alt text](https://g.gravizo.com/svg?
  digraph G {

    b [label="browser" shape="box" style="filled" color="lightgreen" URL="https://github.com/hillar/detektiven/blob/master/chat/browser/README.md"]
    {rank=min; b }

  	subgraph cluster_0 {
  		style=filled;
  		color=lightgreen;
      h [label="" shape="point"]
      w [label="" shape="point"]
      c [label="chat"];
      i [label="history"];
      l [label="ldap"];
      {rank=same; h w }
      {rank=same; c i l}
      l -> c;
      c -> i -> c;
      c -> h [dir="none"];
      w -> c [style="dotted" dir="none"];
  	}

    subgraph cluster_1 {
  		style=filled;
  		color=lightgrey;
      o [label="office"]
      r [label="cache"]
      {rank=same; o r}
      o -> r -> o;
    }

    subgraph cluster_2 {
      style=filled;
      color=lightgrey;
      x [label="ip"]
      y [label="domain"]
      z [label="md5"]
    }

    h -> b
    w -> b [style="dotted" dir=none];

    c -> o -> c

    o -> {x y z} -> o

    x -> {x1 x2 x3} -> x

    y -> {y1 y2} -> y

    z -> {z1 z2 z3 z4} -> z
  }
)
