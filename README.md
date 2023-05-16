# reverse-engineering-kubeconfig
This tool scans your kubeconfig entries for different contexts and authentication methods, reveals certificate contents and error codes.

## Usage
```bash
$ ki
Kubeconfig Path: /home/jj/.kube/config
Number of entries in Kubeconfig: 3

------------------ 0 
Context name       : default
Context cluster    : default
Context user       : default
API Server URL     : https://192.168.0.229:6443
    --> ping       : Yes
    --> can list ns: Yes
Cluster CA included: Yes
    -->      Issuer: CN = k3s-server-ca@1670179571
    -->     Subject: CN = k3s-server-ca@1670179571
    -->     Expires: Dec  1 18:46:11 2032 GMT
Client auth method : Certificate
    -->      Issuer: CN = k3s-client-ca@1670179571
    -->     Subject: O = system:masters, CN = system:admin
    -->     Expires: Dec  4 18:46:11 2023 GMT

------------------ 1 
Context name       : gke_lakis-382409_europe-central2-a_cluster-1
Context cluster    : gke_lakis-382409_europe-central2-a_cluster-1
Context user       : gke_lakis-382409_europe-central2-a_cluster-1
API Server URL     : https://34.118.50.204
    --> ping       : Yes
    --> can list ns: Yes
Cluster CA included: Yes
    -->      Issuer: CN = 0a3175bf-36bb-4a3b-8b4b-26ac015e193f
    -->     Subject: CN = 0a3175bf-36bb-4a3b-8b4b-26ac015e193f
    -->     Expires: May  8 20:02:21 2053 GMT
Client auth method : Command (gke-gcloud-auth-plugin)
    -->     Command: gke-gcloud-auth-plugin
    -->      Output: /tmp/kubecmdtoken-1
    --> Can execute: Yes
    -->      Is JWT: No

------------------ 2 (Current context)
Context name       : akstest
Context cluster    : akstest
Context user       : clusterUser_akstest_akstest
API Server URL     : https://akstest-akstest-64dc1c-ti0khomo.hcp.polandcentral.azmk8s.io:443
    --> ping       : Yes
    --> can list ns: No (Return code 1)
Cluster CA included: Yes
    -->      Issuer: CN = ca
    -->     Subject: CN = ca
    -->     Expires: May 16 20:18:48 2053 GMT
Client auth method : Command (kubelogin)
    -->     Command: kubelogin get-token -l azurecli --server-id 6dae42f8-4368-4678-94ff-3960e28e3630
    -->      Output: /tmp/kubecmdtoken-2
    --> Can execute: Yes
    -->      Is JWT: Yes
    -->      claims: [ "acr", "aio", "altsecid", "amr", "appid", "appidacr", "aud", "email", "exp", "family_name", "given_name", "groups", "iat", "idp", "ipaddr", "iss", "name", "nbf", "oid", "puid", "rh", "scp", "sub", "tid", "unique_name", "uti", "ver", "wids" ]
    --> decoded jwt: /tmp/kubecmd-jwt-2
```
