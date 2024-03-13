if [ root = "$USER" ]; then
	make install
else
	export ZELTA_BIN="$HOME/bin"
	export ZELTA_SHARE="$HOME/.local/share/zelta"
	export ZELTA_ETC="$HOME/.config/zelta"
	echo Installing Zelta as an unprivilaged user. To ensure the per-user setup of
	echo Zelta is being used, please export the following environment variables in
	echo your shell\'s startup scripts:
	echo
	echo export ZELTA_BIN=\"$ZELTA_BIN\"
	echo export ZELTA_SHARE=\"$ZELTA_SHARE\"
	echo export ZELTA_ETC=\"$ZELTA_ETC\"
	echo 
	echo You may also set these variables as desired and rerun this command.
	echo Press Control-C to break or Return to install; read whatever
	make install
fi
