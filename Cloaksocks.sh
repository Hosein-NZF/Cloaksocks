#!/bin/sh

echo
echo
echo  "================================ Cloaksocks =================================="
echo  "=============================================================================="
echo  "============ Shadowsocks over Cloak deployed via docker-compose =============="
echo  "=============================================================================="
echo  "=============================================================================="
echo

InstallDep(){
	# Check if docker is installed
	dpkg -l | grep docker > /dev/null
	if [ $? -eq 1 ]
	then
		apt-get update
		apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
		curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
		apt-get update
		apt-get install -y docker-ce docker-ce-cli containerd.io
		systemctl start docker
	fi
	
	# Check if docker-compose is installed
	docker-compose version > /dev/null
	if [ $? -eq 1 ]
	then
		curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" \
		-o /usr/local/bin/docker-compose
		chmod +x /usr/local/bin/docker-compose
	fi
	
	# Check if qrencode is installed
	dpkg -l | grep qrencode > /dev/null
	if [ $? -eq 1 ]
	then
		apt-get install -y qrencode
	fi
}

QueryInfo(){

	DefIP=$(curl -s https://ipecho.net/plain)
	KEYPAIRS=$(bin/ck_server -key)
	PrivateKey=$(echo $KEYPAIRS | cut -d" " -f13)
	PublicKey=$(echo $KEYPAIRS | cut -d" " -f5)
	CloakUID=$(bin/ck_server -uid | cut -d" " -f4)
}

ReadArgs(){
	read -e -p "Enter IP Address " -i "$DefIP" LOCAL_IP
	read -e -p "Enter Shadowsocks Port: " -i "8399" LOCAL_PORT
	read -e -p "Enter ByPassUID: " -i "$CloakUID" BYPASSUID
	read -e -p "Enter PrivateKey: " -i "$PrivateKey" PRIVATEKEY
	read -e -p "Enter PublicKey: " -i "$PublicKey" PUBLICKEY

	echo "Encryption methods: "
	echo "1) aes-256-gcm"
	echo "2) aes-128-gcm"
	echo "3) chacha20-ietf-poly1305 (Recommended)"
	read -e -p "Select Encryption method (AEAD_CHACHA20_POLY1305 is the default value. Other ciphers might not work.): " -i "3" OPTIONS
	
	case $OPTIONS in
	1)
		ENCRYPTION="AES-256-GCM";;
	2)
		ENCRYPTION="AES-128-GCM";;
	3)
		ENCRYPTION="AEAD_CHACHA20_POLY1305";;
	esac

	ENCRYPTION_LC=$(echo $ENCRYPTION | tr A-Z a-z)


	read -e -p "Enter Cloak Port (443 is strongly recommended): " -i "443" BINDPORT
	stty -echo
	read -p "Enter Password: " -i "" PASSWORD
	stty echo
	echo
	echo

	echo "Enter AdminUID (Optional): "
	echo "1) UseByPassUID as AdminUID"
	echo "2) Generate new UID and set it as AdminUID"
	echo "3) Ignore (Recommended)"
	echo
	read -r -p "Please enter a number: " OPTIONS

	case $OPTIONS in
	1)
		ADMINUID=$BYPASSUID;;
	2)
		ADMINUID=$(bin/ck-server -uid | cut -d" " -f4)
		echo "Your AdminUID: $ADMINUID";;
	*)
		continue;;
	esac

	echo "Enter Redirect Address: "
	echo "1) Cloudflare (1.0.0.1)"
	echo "2) www.bing.com"
	echo
	read -r -p "Select an Option or Enter an Address: " OPTIONS

	case $OPTIONS in
	1)
		REDIRADDR=1.0.0.1;;
	2)
		REDIRADDR=www.bing.com;;
	*)
		REDIRADDR=$OPTIONS;;
	esac
	
	echo "Redirect address set to: $REDIRADDR"
	echo
}

ReplaceArgs(){
	cp docker-compose-server.yaml docker-compose.yml
	sed -i "s|\$LOCAL_IP|${LOCAL_IP}|" docker-compose.yml 
	sed -i "s|\$LOCAL_PORT|${LOCAL_PORT}|g" docker-compose.yml
	sed -i "s|\$BYPASSUID|${BYPASSUID}|" docker-compose.yml
	sed -i "s|\$PRIVATEKEY|${PRIVATEKEY}|" docker-compose.yml
	sed -i "s|\$PUBLICKEY|${PUBLICKEY}|" docker-compose.yml
	sed -i "s|\$ENCRYPTION|${ENCRYPTION}|" docker-compose.yml
	sed -i "s|\$PASSWORD|${PASSWORD}|" docker-compose.yml
	sed -i "s|\$ADMINUID|${ADMINUID}|" docker-compose.yml
	sed -i "s|\$REDIRADDR|${REDIRADDR}|" docker-compose.yml
	sed -i "s|\$BINDPORT|${BINDPORT}|g" docker-compose.yml
}

ShowConnectionInfo(){
	SERVER_BASE64=$(printf "%s" "$ENCRYPTION_LC:$PASSWORD" | base64)
	SERVER_CLOAK_ARGS="ck-client;UID=$BYPASSUID;PublicKey=$PUBLICKEY;ServerName=$REDIRADDR;TicketTimeHint=3600;MaskBrowser=chrome;NumConn=4"
	SERVER_CLOAK_ARGS=$(printf "%s" "$SERVER_CLOAK_ARGS" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" | cut -c 3-)
	SERVER_BASE64="ss://$SERVER_BASE64@$LOCAL_IP:$BINDPORT?plugin=$SERVER_CLOAK_ARGS"

	echo  "=============================================================================="
	echo  "=============================================================================="
	echo "Download Cloak Android Client from https://github.com/cbeuw/Cloak-android/releases"
	echo "Download Cloak PC Client from https://github.com/cbeuw/Cloak/releases"
	echo "Make sure you have the ck-plugin installed and then Scan this QR:"
	echo
	qrencode -t ansiutf8 "$SERVER_BASE64"

	echo  "=============================================================================="
	echo  "=============================================================================="
	echo "Or just use the link below:"
	echo $SERVER_BASE64
	echo
}

if [ -x bin/ck_server ]
then
        QueryInfo
else
        chmod +x bin/ck_server
        QueryInfo
fi

ReadArgs
InstallDep
ReplaceArgs
docker-compose up -d
ShowConnectionInfo
