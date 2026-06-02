### If my pool has a colon `:` in its name, how can I replicate it with Zelta?

The first colon (before a `/` or space) will be interpreted as a host name. Prefix the hostname with **localhost:**, e.g., `localhost:my:pool:name`, and Zelta will do the right thing.

 
### Can I use Zelta without installing it globally?

Yes. For most user-local installs, use the web installer as the target user:

```sh
curl -fsSL https://raw.githubusercontent.com/bell-tower/zelta/main/contrib/web-install.sh | sh
```

You can also run the source installer from a checkout:

```sh
./install.sh
```

The installer shows proposed installation directories before installing. To change the target locations, export the relevant environment variables and rerun `./install.sh`. For development, you can also run it directly out of the repo directory with:

```sh
export PATH="$(pwd)/bin:$PATH"
export ZELTA_SHARE="$(pwd)/share/zelta"
```
