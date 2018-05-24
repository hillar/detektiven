# detektiven in the box

This is partly inspired by https://github.com/fleet-commander/fc-vagans

## Requirements

The setup needs about XX GB of free RAM and YY GB disk space.

## Build

```shell
$ cd yourfavouritedirectoryname
$ curl -s https://raw.githubusercontent.com/hillar/detektiven/master/vagans/getit.bash | bash
$ cd detektiven/scripts
$ more getup.bash
$ chmod +x getup.bash
$ time ./getup.bash
```

### Why a shell script!?
The script is meant to be read by humans (as well as ran by computers); it is the primary documentation after all. Using a recipe system requires everyone to agree and understand salt or chef or puppet or ...  
