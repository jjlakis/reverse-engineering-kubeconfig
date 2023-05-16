# reverse-engineering-kubeconfig
This tool scans your kubeconfig entries for different contexts and authentication methods, reveals certificate contents and error codes.

## Usage
```bash
$ ki
Kubeconfig Path: /home/jj/.kube/config
Number of entries in Kubeconfig: 1

------------------ 0 (Current context)
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
```
