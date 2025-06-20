#!/bin/bash
NGINX_DIR="/etc/nginx"
HOSTNAME=$(hostname)

if [ ! -d "$NGINX_DIR" ]; then
	exit
fi
rm $NGINX_DIR/site-*/*
TEMP_HOST_FILE=`mktemp`
cp /etc/hosts $TEMP_HOST_FILE
INDENT=4

function appendProxyServerBlock() {
	INDENT=$((INDENT+4))
	local DOMAIN
	local PORT
	local INCLUDE_DOMAIN
	local SSL
	local FILE
	DOMAIN=$1
	PORT=$2
	INCLUDE_DOMAIN=$3
	FILE=$4
	if [[ "$5" == "ssl" ]]; then
		SSL=" ssl"
	fi

	if [[ -z "$DOMAIN" || -z "$INCLUDE_DOMAIN" ]]; then
		return
	fi
	echo "$(echo "" | pr -to $INDENT)append proxy server block: '${DOMAIN}'${SSL}"
	cat >> "$FILE" << EOF
server {
	listen ${PORT}${SSL};

	server_name ${DOMAIN};
EOF

	if [[ ! -z "$SSL" ]]; then
		cat >> "$FILE" << EOF

	ssl_certificate /etc/nginx/ssl/${DOMAIN}/server.crt;
	ssl_certificate_key /etc/nginx/ssl/${DOMAIN}/server.key;

	add_header Strict-Transport-Security max-age=15552000;
EOF
	else
		cat >> "$FILE" << EOF
	server_name www.${DOMAIN};
EOF
	fi

	cat >> "$FILE" << EOF
	root /var/www;

	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header Host \$http_host;
	proxy_set_header X-Forwarded-Proto \$scheme;
	proxy_set_header X-Real-IP \$remote_addr;

	# WebSocket support
	proxy_http_version 1.1;
	proxy_set_header Upgrade \$http_upgrade;
	proxy_set_header Connection \$connection_upgrade;

	proxy_redirect off;
	location /.well-known/acme-challenge {
		root /tmp/acme;
	}

	include /etc/nginx/site-${INCLUDE_DOMAIN}/*;
}
EOF
	INDENT=$((INDENT-4))
}

function appendProxy() {
	INDENT=$((INDENT+4))
	local DOMAIN
	local INCLUDE_DOMAIN
	local FILE
	DOMAIN=$1
	INCLUDE_DOMAIN=$2
	FILE="$NGINX_DIR/sites-enabled/${DOMAIN}"


	if [[ -z "$TARGET_PUBLIC_PORT" ]]; then
		TARGET_PUBLIC_PORT=80
	fi

	if [[ -z "$TARGET_PUBLIC_PORT_SSL" ]]; then
		TARGET_PUBLIC_PORT_SSL=443
	fi

	echo "$(echo "" | pr -to $INDENT)creating proxy for domain ${DOMAIN}"
	#VHost-Datei leeren
	printf "" > "$FILE"

	#Proxy mit ssl (redirect HTTP -> HTTPS)
	if [ -f "$NGINX_DIR/ssl/${DOMAIN}/server.crt" ]; then

		if [ -f "$NGINX_DIR/ssl/${DOMAIN}/allow_http" ]; then
			appendProxyServerBlock "${DOMAIN}" "${TARGET_PUBLIC_PORT}" "${INCLUDE_DOMAIN}" "$FILE"
		else
			cat >> "${FILE}" << EOF
server {
	listen ${TARGET_PUBLIC_PORT};
	server_name ${DOMAIN};
	server_name www.${DOMAIN};
	location /.well-known/acme-challenge {
		root /tmp/acme;
	}
	root /var/www;
	${CUSTOM_NGINX_HTTP_CONFIG}

	add_header Strict-Transport-Security max-age=15552000;
	location / {
		return 301 https://${DOMAIN}:${TARGET_PUBLIC_PORT_SSL}\$request_uri;
	}
}
EOF
		fi
		appendProxyServerBlock "${DOMAIN}" "${TARGET_PUBLIC_PORT_SSL}" "${INCLUDE_DOMAIN}" "$FILE" "ssl"

	# Proxy ohne ssl
	else
		appendProxyServerBlock "${DOMAIN}" "${TARGET_PUBLIC_PORT}" "${INCLUDE_DOMAIN}" "$FILE"
	fi
	INDENT=$((INDENT-4))
}

function configureProxyForTargetDomain() {
	INDENT=$((INDENT+4))
	local DOMAIN=$1

	echo "$(echo "" | pr -to $INDENT)configure proxy for domain $DOMAIN"
	appendProxy "${DOMAIN}" "${DOMAIN}"

	# Proxy für Domain mit www Präfix
	if [ -f "$NGINX_DIR/ssl/www.${DOMAIN}/server.crt" ]; then
		FILE="$NGINX_DIR/sites-enabled/www.${DOMAIN}"
		printf "" > "$FILE"
		appendProxyServerBlock "www.${DOMAIN}" "${TARGET_PUBLIC_PORT_SSL}" "${DOMAIN}" "$FILE" "ssl"
	fi

	mkdir -p "$NGINX_DIR/site-${DOMAIN}"
	if [[ -z "$PROXY_CONTEXTS" ]]; then
		if [[ -z "$CONTAINER_HTTPS_PORT" ]]; then
			cat >> $NGINX_DIR/site-${DOMAIN}/${TARGET_CONTAINER} << EOF
				location / {
					proxy_pass http://${CONTAINER_IP}:${CONTAINER_HTTP_PORT};
				}
EOF
		else
			cat >> $NGINX_DIR/site-${DOMAIN}/${TARGET_CONTAINER} << EOF
				location / {
					proxy_pass https://${CONTAINER_IP}:${CONTAINER_HTTPS_PORT};
				}
EOF
		fi
	else
		if [[ ! -z "$ROOT_REDIRECT" ]]; then
			cat >> $NGINX_DIR/site-${DOMAIN}/${TARGET_CONTAINER} << EOF
				location = / {
					return 302 \$scheme://${DOMAIN}/${ROOT_REDIRECT};
				}
EOF
		fi
		for PROXY_CONTEXT in $PROXY_CONTEXTS; do
			if [[ -z "$CONTAINER_HTTPS_PORT" ]]; then
				cat >> $NGINX_DIR/site-${DOMAIN}/${TARGET_CONTAINER} << EOF
					location /${PROXY_CONTEXT} {
						proxy_pass http://${CONTAINER_IP}:${CONTAINER_HTTP_PORT}/${PROXY_CONTEXT};
					}
EOF
			else
				cat >> $NGINX_DIR/site-${DOMAIN}/${TARGET_CONTAINER} << EOF
					location /${PROXY_CONTEXT} {
						proxy_pass https://${CONTAINER_IP}:${CONTAINER_HTTPS_PORT}/${PROXY_CONTEXT};
					}
EOF
			fi
		done;
	fi


	CONTAINER_CONFIG_DIR="/invra/state/$(cat /invra/hostowner)/containers"
	for FWD in $PROXY_FORWARDS; do
		SOURCE_PATH="`echo $FWD | cut -d: -f1`"
		TARGET_URL="`echo $FWD | cut -d: -s -f2-`"
		CONTINUE=0

		# Prüfen ob Proxy bereits durch neues Schema im invra/state angelegt wurde
		while read PROXY_FILE; do
			CUR_HOST_FILE="$(dirname "$(dirname "$PROXY_FILE")")/current-host"
			CUR_HOST=$(cat $CUR_HOST_FILE)
			if [[ -f "$CUR_HOST_FILE" && ( "$CUR_HOST" != "$HOSTNAME" || "$DOMAIN" != "$HOSTNAME" ) ]]; then
				CONTINUE=1
				break
			fi
		#Process Substitution nutzen, damit CONTINUE-Variable die Schleife überlebt
		done < <(grep -lER "^/?${SOURCE_PATH}/?$" ${CONTAINER_CONFIG_DIR}/*/httpproxy/${DOMAIN} 2> /dev/null)

		if [ $CONTINUE -eq 1 ]; then
			continue
		fi
		echo "$(echo "" | pr -to $INDENT)create proxy for context-path '${SOURCE_PATH}' to URL '${TARGET_URL}'"
		cat >> $NGINX_DIR/site-${DOMAIN}/${TARGET_CONTAINER} << EOF
				location /${SOURCE_PATH} {
					proxy_pass ${TARGET_URL};
				}
EOF

	done
	INDENT=$((INDENT-4))
}

function getVar() {
	local _VAR_NAME=$1
	local _CONF_FILE=$2
	local _RESULT
	_RESULT=$(grep -E "^${_VAR_NAME}=" "${_CONF_FILE}" | grep -oE "[^=]+$")
	_CLEAN_RESULT=$(echo "$_RESULT" | sed -E 's/[()"]//g')
	GET_VAR_RESULT=$_CLEAN_RESULT
}

echo "creating proxy forwards..."
TARGET_PUBLIC_PORT=""
TARGET_PUBLIC_PORT_SSL=""
for CONTAINER in /invra/state/$(cat /invra/hostowner)/containers/*; do
	CONTAINER_HOST="$(cat $CONTAINER/current-host)"
	TARGET_CONTAINER="$(basename "$CONTAINER")"

	echo "    creating forward proxies for container '${TARGET_CONTAINER}' on Host '${CONTAINER_HOST}'"
	for DOMAIN_FILE in $CONTAINER/httpproxy/*; do
		if [ ! -f "${DOMAIN_FILE}" ]; then
			continue
		fi

		TARGET_DOMAIN="$(basename "$DOMAIN_FILE")"

		#Proxy für Domain, die direkt auf diesen Host verweisen, überspringen => werden für die gehosteten Containern später angelegt
		if [[ "$TARGET_DOMAIN" == "$HOSTNAME" && "$CONTAINER_HOST" == "$HOSTNAME" ]]; then
			echo "    skipping '${TARGET_DOMAIN}'"
			continue
		fi

		appendProxy "${TARGET_DOMAIN}" "${TARGET_DOMAIN}"

		cat "$DOMAIN_FILE" | while read PROXY_CONTEXT; do

			echo "            with context path '${PROXY_CONTEXT}'"

			mkdir -p "$NGINX_DIR/site-${TARGET_DOMAIN}"
			case $PROXY_CONTEXT in
				/) TARGET_LOCATION="" ;;
				/*) TARGET_LOCATION="${PROXY_CONTEXT}" ;;
				*) TARGET_LOCATION="/${PROXY_CONTEXT}"; PROXY_CONTEXT="${TARGET_LOCATION}" ;;
			esac

			if [[ "$CONTAINER_HOST" == "$HOSTNAME" ]]; then
				# neuer docker client
				CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}:{{end}}' $TARGET_CONTAINER | cut -d: -f1)
				if [ -z "$CONTAINER_IP" ]; then
					# alter docker client
					CONTAINER_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' $TARGET_CONTAINER)
					if [ -z "$CONTAINER_IP" ]; then
						continue
					fi
				fi
				CONTAINER_CONFIG="/persistent/${TARGET_CONTAINER}/containersettings"
				getVar "CONTAINER_HTTP_PORT" "${CONTAINER_CONFIG}"
				CONTAINER_HTTP_PORT=${GET_VAR_RESULT:-8080}

				cat >> "$NGINX_DIR/site-${TARGET_DOMAIN}/${TARGET_CONTAINER}" << EOF
					location ${PROXY_CONTEXT} {
						proxy_pass http://${CONTAINER_IP}:${CONTAINER_HTTP_PORT};
					}
EOF
				CONTAINER_CONFIG=""
				CONTAINER_HTTP_PORT=""
			else
				cat >> "$NGINX_DIR/site-${TARGET_DOMAIN}/fw-${TARGET_CONTAINER}" << EOF
					location ${PROXY_CONTEXT} {
						proxy_pass https://${CONTAINER_HOST}${TARGET_LOCATION};
						proxy_set_header Host ${TARGET_DOMAIN};
					}
EOF
			fi
		done
	done
done

echo ""
echo "creating proxies for local container..."
for CONTAINER_CONFIG in /persistent/*/containersettings; do

	getVar "TARGET_CONTAINER" "${CONTAINER_CONFIG}"
	TARGET_CONTAINER=$GET_VAR_RESULT
	getVar "CONTAINER_HTTP_PORT" "${CONTAINER_CONFIG}"
	CONTAINER_HTTP_PORT=${GET_VAR_RESULT:-8080}
	getVar "CONTAINER_HTTPS_PORT" "${CONTAINER_CONFIG}"
	CONTAINER_HTTPS_PORT=$GET_VAR_RESULT
	getVar "TARGET_DOMAIN" "${CONTAINER_CONFIG}"
	TARGET_DOMAIN=$GET_VAR_RESULT
	getVar "TARGET_PUBLIC_PORT" "${CONTAINER_CONFIG}"
	TARGET_PUBLIC_PORT=$GET_VAR_RESULT
	getVar "TARGET_PUBLIC_PORT_SSL" "${CONTAINER_CONFIG}"
	TARGET_PUBLIC_PORT_SSL=$GET_VAR_RESULT
	getVar "ADDITIONAL_TARGET_DOMAIN" "${CONTAINER_CONFIG}"
	ADDITIONAL_TARGET_DOMAIN=$GET_VAR_RESULT
	getVar "PROXY_CONTEXTS" "${CONTAINER_CONFIG}"
	PROXY_CONTEXTS=$GET_VAR_RESULT
	getVar "PROXY_FORWARDS" "${CONTAINER_CONFIG}"
	PROXY_FORWARDS=$GET_VAR_RESULT
	getVar "CUSTOM_NGINX_HTTP_CONFIG" "${CONTAINER_CONFIG}"
	CUSTOM_NGINX_HTTP_CONFIG=""
	grep -E "CUSTOM_NGINX_HTTP_CONFIG" "${CONTAINER_CONFIG}" > /dev/null 
	if [[ $? -eq 0 ]]; then
		echo "CUSTOM_NGINX_HTTP_CONFIG wird in containersettings nicht mehr unterstützt"
	fi
	getVar "ROOT_REDIRECT" "${CONTAINER_CONFIG}"
	ROOT_REDIRECT=$GET_VAR_RESULT

	if [[ "${TARGET_CONTAINER}" == "" ]]; then
		echo "'${CONTAINER_CONFIG}' enthält keinen TARGET_CONTAINER"
		continue
	fi

	CURRENT_HOST_FILE="/invra/state/$(cat /invra/hostowner)/containers/${TARGET_CONTAINER}/current-host"
	if [ -f "$CURRENT_HOST_FILE" ]; then
		CURRENT_HOST="$(cat "$CURRENT_HOST_FILE")"
		if [ ! -z "$CURRENT_HOST" ] && [[ "$CURRENT_HOST" != "$HOSTNAME" ]]; then
			continue
		fi
	fi
	echo "    configuring container '$TARGET_CONTAINER'"
	# neuer docker client
	CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}:{{end}}' $TARGET_CONTAINER | cut -d: -f1)
	if [ -z "$CONTAINER_IP" ]; then
		# alter docker client
		CONTAINER_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' $TARGET_CONTAINER)
		if [ -z "$CONTAINER_IP" ]; then
			continue
		fi
	fi
	echo "        updating ip from container $TARGET_CONTAINER"
	sed -i "s/.*$TARGET_CONTAINER\.cont.*//" $TEMP_HOST_FILE
	sed -i '/^\s*$/d' "${TEMP_HOST_FILE}" #löscht alle Zeilen, die nur unsichtbare Zeichen enthalten
	sed -i "/# DOCKER-IPS/a\\$CONTAINER_IP $TARGET_CONTAINER\.cont" $TEMP_HOST_FILE

	if [ -z "$TARGET_DOMAIN" ]; then
		continue
	fi

	for DOMAIN_I in ${TARGET_DOMAIN}; do
		OLDSETTINGSFILE="$NGINX_DIR/site-${DOMAIN_I}/${TARGET_CONTAINER}"
		if [ -f $OLDSETTINGSFILE ]; then
			rm $OLDSETTINGSFILE
		fi
		configureProxyForTargetDomain "${DOMAIN_I}"
	done

	if [[ ! -z "${ADDITIONAL_TARGET_DOMAIN}" ]]; then
		for DOMAIN_I in ${ADDITIONAL_TARGET_DOMAIN}; do
			appendProxy "${DOMAIN_I}" "$(echo ${TARGET_DOMAIN} | awk '{print $1}')"
		done
	fi

done
cat $TEMP_HOST_FILE > /etc/hosts
rm $TEMP_HOST_FILE
service nginx configtest
service nginx reload

