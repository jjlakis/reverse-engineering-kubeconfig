#!/bin/bash

function jwt_decode(){
	    jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$1"
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
                ISSUER=$(echo $CLUSTER_CA | base64 -d | openssl x509 -in - -text -noout | grep Issuer | sed -e 's/^[ \t]*//' | sed 's/Issuer: //g')
                SUBJECT=$(echo $CLUSTER_CA | base64 -d | openssl x509 -in - -text -noout | grep Subject: | sed -e 's/^[ \t]*//' | sed 's/Subject: //g')
                EXP=$(echo $CLUSTER_CA | base64 -d | openssl x509 -in - -enddate -noout | sed 's/notAfter=//g')

                echo "    -->      Issuer: $ISSUER"
                echo "    -->     Subject: $SUBJECT"
                #echo "    -->     Expires: $EXP"

        else
                echo "No"
        fi


        echo -n "Client auth method : "
        if [ ! "$CLIENT_CERT" == "null" ]
        then
                echo "Certificate"
                ISSUER=$(echo $CLIENT_CERT | base64 -d | openssl x509 -in - -text -noout | grep Issuer | sed -e 's/^[ \t]*//' | sed 's/Issuer: //g')
                SUBJECT=$(echo $CLIENT_CERT | base64 -d | openssl x509 -in - -text -noout | grep Subject: | sed -e 's/^[ \t]*//' | sed 's/Subject: //g')
                EXP=$(echo $CLIENT_CERT | base64 -d | openssl x509 -in - -enddate -noout | sed 's/notAfter=//g')

                echo "    -->      Issuer: $ISSUER"
                echo "    -->     Subject: $SUBJECT"
                echo "    -->     Expires: $EXP"

	elif [ ! "$CLIENT_EXEC_COMMAND" == "null" ];
	then
		echo "Command ($CLIENT_EXEC_COMMAND)"
		echo    "    -->     Command: $CLIENT_EXEC_COMMAND" $CLIENT_EXEC_ARGS
		echo    "    -->      output: /tmp/kubecmdtoken-$I" 
		echo -n "    -->    can read: "

		timeout 2 $CLIENT_EXEC_COMMAND $CLIENT_EXEC_ARGS &>  /tmp/kubecmdtoken-$I
		TOKEN_REQUEST_RC=$?


		if [ "$TOKEN_REQUEST_RC" == "124" ]
		then
			echo "No (Timeout). Interactive shell / device login?"
		elif  [ ! "$TOKEN_REQUEST_RC" == "0" ]
		then
			echo "No (Error code: $TOKEN_REQUEST_RC)"
		else
			echo "Yes. JWT"
			TOKEN=$(cat /tmp/kubecmdtoken-$I | jq -r .status.token)
			CLAIMS=$(jwt_decode $TOKEN | jq -r keys)
			jwt_decode $TOKEN > /tmp/kubecmd-jwt-$I
			echo "    -->      claims:" $CLAIMS
			echo "    --> decoded jwt: /tmp/kubecmd-jwt-$I"
		fi


	else
		echo "Uknown"
	fi


        echo
        ((I++))
done
