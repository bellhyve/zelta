### If my pool has a colon `:` in its name, how can I replicate it with Zelta?

The first colon (before a `/` or space) will be interpreted as a host name. Prefix the hostname with **localhost:**, e.g., `localhost:my:pool:name`, and Zelta will do the right thing.

 
### Can I use Zelta without installing it globally?

You bet! `cd zelta` or your downloaded repo directory and run:

```sh
./install.sh
```

The installer will give a chance to see proposed installation directories before installing. To change the target locations, simply export the environment variables accordingly and rerun `./install.sh`. You can also run it directly out of the repo directory with:

```sh
export PATH=`pwd`/bin:$PATH
export ZELTA_SHARE=`pwd`/share/zelta
```
