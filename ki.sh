#!/bin/bash

function jwt_decode(){
	    jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$1"
    }

function print_certificate_summary(){
		IDENTIFIER=$RANDOM

		echo $1 | base64 -d > /tmp/certificate-$IDENTIFIER
		ISSUER=$(openssl x509 -in /tmp/certificate-$IDENTIFIER -text -noout | grep Issuer | sed -e 's/^[ \t]*//' | sed 's/Issuer: //g')
		SUBJECT=$(openssl x509 -in /tmp/certificate-$IDENTIFIER -text -noout | grep Subject: | sed -e 's/^[ \t]*//' | sed 's/Subject: //g')
		EXP=$(openssl x509 -in /tmp/certificate-$IDENTIFIER -enddate -noout | sed 's/notAfter=//g')

		rm -rf /tmp/certificate-$IDENTIFIER

		echo "    -->      Issuer: $ISSUER"
		echo "    -->     Subject: $SUBJECT"
		echo "    -->     Expires: $EXP"

	}

KUBECONFIG_PATH=${1:-"$HOME/.kube/config"}

CONTEXTS=$(cat $KUBECONFIG_PATH | yq '.contexts[].name')
CURRENT=$(cat $KUBECONFIG_PATH | yq '.current-context')


echo "Kubeconfig Path: $KUBECONFIG_PATH"
echo "Number of entries in Kubeconfig: $(echo $CONTEXTS | wc -w)"

echo
I=0
for CONTEXT in ${CONTEXTS[*]}; do
        IS_CURRENT=
        if [ "$CONTEXT" == "$CURRENT" ]; then
                IS_CURRENT="(Current context)"
        fi

        echo "------------------ $I $IS_CURRENT"

        CLUSTER=$(cat $KUBECONFIG_PATH | yq -r '.contexts.[] | select(.name == "'$CONTEXT'") | .context.cluster')
        USER=$(cat $KUBECONFIG_PATH | yq -r '.contexts.[] | select(.name == "'$CONTEXT'") | .context.user')
        SERVER=$(cat $KUBECONFIG_PATH | yq '.clusters.[] | select(.name == "'$CLUSTER'") | .cluster.server')
        CLUSTER_CA=$(cat $KUBECONFIG_PATH | yq '.clusters.[] | select(.name == "'$CLUSTER'") | .cluster.certificate-authority-data')
        CLIENT_CERT=$(cat $KUBECONFIG_PATH | yq '.users.[] | select(.name == "'$USER'") |.user.client-certificate-data')
        CLIENT_EXEC_COMMAND=$(cat $KUBECONFIG_PATH | yq '.users.[] | select(.name == "'$USER'") |.user.exec.command')
        CLIENT_EXEC_ARGS=$(cat $KUBECONFIG_PATH | yq '.users.[] | select(.name == "'$USER'") |.user.exec.args.[]')

        echo    "Context name       : $CONTEXT"
        echo    "Context cluster    : $CLUSTER"
        echo    "Context user       : $USER"
        echo    "API Server URL     : $SERVER"

	echo -n "    --> ping       : "

	SERVER_NO_SCHEME=$(echo $SERVER | sed 's/https\:\/\///g' | sed 's/http\:\/\///g' | awk -F ':' '{print $1}')
	timeout 2 ping -c 2 $SERVER_NO_SCHEME &> /dev/null
	PING_RESULT=$?

	if [ "$PING_RESULT" == "0" ];
	then
		echo "Yes"
	elif [ "$PING_RESULT" == "124" ];
	then
		echo "No (Timeout)"
	else
		echo "No (Return code $PING_RESULT)"
	fi


        echo  -n "    --> can list ns: "
	timeout 3 kubectl --context $CONTEXT get namespaces &> /dev/null
	GET_NS_RESULT=$?
	if [ "$GET_NS_RESULT" == "0" ];
	then
		echo "Yes"
	elif [ "$GET_NS_RESULT" == "124" ];
	then
		echo "No (Timeout)"
	else
		echo "No (Return code $GET_NS_RESULT)"
	fi

        echo -n "Cluster CA included: "

        if [ ! "$CLUSTER_CA" == "null" ]
        then
                echo "Yes"
                print_certificate_summary $CLUSTER_CA

        else
                echo "No"
        fi


        echo -n "Client auth method : "
        if [ ! "$CLIENT_CERT" == "null" ]
        then
                echo "Certificate"
                print_certificate_summary $CLIENT_CERT


	elif [ ! "$CLIENT_EXEC_COMMAND" == "null" ];
	then
		echo "Command ($CLIENT_EXEC_COMMAND)"
		echo    "    -->     Command: $CLIENT_EXEC_COMMAND" $CLIENT_EXEC_ARGS
		echo    "    -->      Output: /tmp/kubecmdtoken-$I"
		echo -n "    --> Can execute: "

		timeout 2 $CLIENT_EXEC_COMMAND $CLIENT_EXEC_ARGS &>  /tmp/kubecmdtoken-$I
		TOKEN_REQUEST_RC=$?


		if [ "$TOKEN_REQUEST_RC" == "124" ]
		then
			echo "No (Timeout). Interactive shell / device login?"
		elif  [ ! "$TOKEN_REQUEST_RC" == "0" ]
		then
			echo "No (Error code: $TOKEN_REQUEST_RC)"
		else
			echo "Yes"
			TOKEN=$(cat /tmp/kubecmdtoken-$I | jq -r .status.token)
		fi

		echo -n "    -->      Is JWT: "

		# Check if we can decode JWT
		jwt_decode $TOKEN &> /tmp/kubecmd-jwt-$I
		JWT_DECODE_RC=$?

		if [ "$JWT_DECODE_RC" == "0" ]
		then
			echo "Yes"
			CLAIMS=$(jwt_decode $TOKEN | jq -r keys)
			echo "    -->      claims:" $CLAIMS
			echo "    --> decoded jwt: /tmp/kubecmd-jwt-$I"
		else
			echo "No"
		fi
	else
		echo "Unknown"
	fi


        echo
        ((I++))
done
