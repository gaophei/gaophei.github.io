

### 2. kubectl context设置---注意集群的不同

```bash
精简命令：
# kubectl config get-contextx
# kubectl config current-context

# kubectl config use-context kubernetes-admin@kubernetes

# ssh k8s-node-0
# sudo -i
```



```bash
详细分析：
# kubectl config --help
${HOME}/.kube/config is used

Available Commands:
  current-context   Display the current-context
  delete-cluster    Delete the specified cluster from the kubeconfig
  delete-context    Delete the specified context from the kubeconfig
  delete-user       Delete the specified user from the kubeconfig
  get-clusters      Display clusters defined in the kubeconfig
  get-contexts      Describe one or many contexts
  get-users         Display users defined in the kubeconfig
  rename-context    Rename a context from the kubeconfig file
  set               Set an individual value in a kubeconfig file
  set-cluster       Set a cluster entry in kubeconfig
  set-context       Set a context entry in kubeconfig
  set-credentials   Set a user entry in kubeconfig
  unset             Unset an individual value in a kubeconfig file
  use-context       Set the current-context in a kubeconfig file
  view              Display merged kubeconfig settings or a specified kubeconfig file

Usage:
  kubectl config SUBCOMMAND [options]

# cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJek1EUXdOekE1TVRJME5Wb1hEVE16TURRd05EQTVNVEkwTlZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTTdKCks5R1hHaSt1anNJNHZjbnRoYnBmd2xtcEg0K3lsbWtkSGt4OHpIUlZDS1U4RnBjSFlOSXMzeTZGK2N1TStrb1QKKyt3NnoyQUJrQ3ozZHZYVjBhaVZvTU1kajhQTjBVQVMrMGFTczZ4bW41cHVPa09iaTY5MVRzZmNDNS8rcFdQOQpJRHE2dmI4N2dSZEgyR2MzWjAvQS9RdE0wMysxZEFxK0FHc3BPYmUwb3B5cUNVT2t3V2QrdTl0STRXZ293NDBUCkEyUmFnUWNjLzc5aXJWSUEzWDFMNTZaZGwwdVpxbmJMeU9qc291d2VHT1gvV2FWb3RrZ2pQRHFaUUczT05vcUQKNXpvajZuYTJTRWxqcmVBT3c2OWRJYlppd0dFOEhuNUI2SjcvdVhlaW1XOUUzdEw0K2VoaE5SU2lVeFhzTUNpdgo5Z3M4QVFMaGVoTjZWNFJwQ2FzQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZNZk9zZGQ1S29aaTJJcHB6UE4zQlJOaGo4aEpNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBRi9LUFhNeTJZUDRRYTJWL2srQwp4eFR1NVd4V2RTUzlTdkpwYkI0bXNRMkpKdmVzRU9xSHQvUEpQNUJ2SmhWdVZ6R25JaDdIRG54NEtwOUVLKytTCkVsWk5zeHhFa0kxNGVOMTNsZ3NOZWlqbHhhV2QydGg1a09xMWNOTDFZRVRodHhrRGd2dDl3TS82TWd1OTRnQ3cKN1hHY29lWVRDV1ptY3hBT0pjcUZDTnlCTnBIUEt5WHRwL2JlbEJEQndRUW94QlhGdDRTT2pxTWlsTEVqalZQcQpkbzN2QkZVNDhMaGk5SjBiQVE4YVFLeDVSUzN0MXV3LzVKTmlQeDhsY0JhbW9vUXREaVRsNTliNEhXYTB5aUJkCnh1b0tLSUxmS3NSQ0hYaUNDOXAwYmRVcW1MWnI3aUJxZ1EwaEVyelFac2V1UURNSTZMTEdPM1EzdGNYVHJiTDcKNGRJPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://192.168.1.234:6443
  name: kubernetes
- cluster:
    certificate-authority-data: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURGVENDQ\
      WYyZ0F3SUJBZ0lKQUtEcTVwSlYzZHhVTUEwR0NTcUdTSWIzRFFFQkN3VUFNQ0V4Q3pBSkJnTlYKQ\
      kFZVEFrTk9NUkl3RUFZRFZRUUREQWxqWVhSMGJHVXRZMkV3SGhjTk1qQXhNREU1TURRd01qQXpXa\
      GNOTXpBeApNREUzTURRd01qQXpXakFoTVFzd0NRWURWUVFHRXdKRFRqRVNNQkFHQTFVRUF3d0pZM\
      kYwZEd4bExXTmhNSUlCCklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUFzN\
      mpQM2c2U2hjc21YU2RraGhKNEIzWDQKcTNrUnpOTXVERlJGQnhab3lkaDdxMmZtcFQ5VkRLRWk0Z\
      TNlNTVvSTBrRWlQaklPeTZCcURFa3hYN1hvVWpycAplNVFMbFdjeWp3TVhVN05YRnJRSWkxQ0dye\
      lJPL1FJVGs3RngrT01iZHBkWDhkaXYzOFEzN3lwM2hRaGhmV0dLCnVJSWJFM2haWkNqWFNSR0ltd\
      FpZZmZhYmJrTVRSb3p2UjNaNlpUSENlamlwdlZsTHdSbzlFK3lGSCtCSmR0eGUKMzA1VUhuRGlvN\
      01jbnJpQkQxVkp1RFZzMmludGhvZ2JFTGJrU0tDUWM3cUg3enJNS1cyZVoxZkgxZ29yeXlDcgpFL\
      24yMSt1V0VqdTUrYWw0ZlZJZnl0L01CZ1RKN3FkWkZQUFZqWUdoNnpYSHhpSlE5NjkvZnU5TVhGZ\
      XQ0d0lECkFRQUJvMUF3VGpBZEJnTlZIUTRFRmdRVWVjWEtQcUZXSlRZUEQ3ZnExZWQxNTBmZGF3U\
      XdId1lEVlIwakJCZ3cKRm9BVWVjWEtQcUZXSlRZUEQ3ZnExZWQxNTBmZGF3UXdEQVlEVlIwVEJBV\
      XdBd0VCL3pBTkJna3Foa2lHOXcwQgpBUXNGQUFPQ0FRRUFva3JJZVZLUVZHTUxHa1dEa1lqSEpGM\
      FRmVEZNekdadzN6WEdyK2xQQWRLY09xMEx0NVR2Cmovbm1qS1lkdkwzVFhxM0t3Sm4rakdtSldMc\
      2RGWVRHUXVqbko1NE1HNDVZMEJFMzBOckgzMXJCNXQxdUFLWkIKUFhYTm9ETy9lTSt6Rk44SHp1S\
      2I3RTBEQ0EvdHNpQzFLY0Y0TUEvc1c1SDJEL1pqckdYZDc5R1BiUUx1cThIZQpLU1hXZ0dpSU1Sd\
      1VWcm1uWEJ2b0NnMGNwV1AvdDJFL3FRdlVUb0ZKRzZFNlNOOXBHYzF5THlSTE52NENiaS9KCnFpU\
      EtQbkd4VUIySG45b3h4dWNRdElMcmVCRVJrWG5Gc2RQYlRKVHREekRtMmJIdGc4UEd1aEtoSnFrY\
      XlndFUKUkd0d29rZS8zb3U5UUZ6VzJSOXQ5VE10VVF1VzgrWGl5dz09Ci0tLS0tRU5EIENFUlRJR\
      klDQVRFLS0tLS0="
    server: "https://rancher.hello-supwisdom.edu.cn/k8s/clusters/c-zpjp2"
  name: rancher-production
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
- context:
    cluster: rancher-production
    user: rancher-admin
  name: rancher-admin@rancher-production
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURJVENDQWdtZ0F3SUJBZ0lJYmRRcEZhYzFHRG93RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TXpBME1EY3dPVEV5TkRWYUZ3MHlOREEwTURZd09URXlORGxhTURReApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sa3dGd1lEVlFRREV4QnJkV0psY201bGRHVnpMV0ZrCmJXbHVNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQW0vMmFGRUNuRThXdmhEeE0KaHlyMjZQY0V2RmxyOHNoQ2pPRlRvTzdpa1c0SjJrZ2lwSE1tN0ZKcGNQSHpDOVZZSHRHQUUyRGdlZEdQd0NYbAplTVk2dUh0ZkxDOGRFS3JUdm1kZEEzUCswQlpRWVBTbkJ3V3ZFZWVJU2tZRlBiZzlPekN0K1Nkc09mbmlTMzdRCkV1d1RCN3NhaTBaQi9pWlRtbjlwSHd1QWFJdXlxL0NPT1p2NysrUTA4M2xKM3pLaVFra1h3MFhJLzhvU1FRaGYKWmlnNUhrblI4cktqZzdjSmxuMHJOTkM2OWhObmx1MlN3NUNTM01JSzkyM2tic0NxMUlmV2kvdHJNWVlNVG8vWQpOSzBjTUQvNWN6OUo5ZmJFNm8xcHpKTCswQlZuYnZNemJjMjRnZjBWR2hhcVpnVE5KeENvT0c2UzVyOHJCS3QzCjVvU2xoUUlEQVFBQm8xWXdWREFPQmdOVkhROEJBZjhFQkFNQ0JhQXdFd1lEVlIwbEJBd3dDZ1lJS3dZQkJRVUgKQXdJd0RBWURWUjBUQVFIL0JBSXdBREFmQmdOVkhTTUVHREFXZ0JUSHpySFhlU3FHWXRpS2Fjenpkd1VUWVkvSQpTVEFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBRHVIMjNZRmFwQTFQVU1ySS9Vcnd6N3AyUXYrRFIyZWdNc04wCkw3WUJVY3VkZXM0LzFET085dTRzRjRFUFlxcFJteDNEb25YNEl0UHN3ZzF3M1BPVHNYNTlacFdoc1NzbmNkZE0KcGU3NWhJMlFUTzlPQlZHVUZjNXBvQkVTNzJkSUx0R01RUXMxcmtlOUVSU3BBeFY2TkxYeUN2QTROT0puVm0vUwoyUCtpbmcyVXlocGpYVWk2KzJOeDlHSFZQVkhUTXBIZ01oL0dLSmpiTUQwd3ZyRmdIWnFWU0NaWWJYRXV0UUFXCmZaUnNXNko4bzUzY0VtSHR3Y3VOcSs2bFVUQnNKMTZoZ0Zubkt1dzRFNFdBUEZpdjRmN25WVVpBeXhPYnlyNXkKelNiYnNYU0JMSW9Wc0hVL0lRd0I1L0VPTHpZbTg5dXp5cHB6aUtMUFY1RWF2cEE1S2c9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBbS8yYUZFQ25FOFd2aER4TWh5cjI2UGNFdkZscjhzaENqT0ZUb083aWtXNEoya2dpCnBITW03RkpwY1BIekM5VllIdEdBRTJEZ2VkR1B3Q1hsZU1ZNnVIdGZMQzhkRUtyVHZtZGRBM1ArMEJaUVlQU24KQndXdkVlZUlTa1lGUGJnOU96Q3QrU2RzT2ZuaVMzN1FFdXdUQjdzYWkwWkIvaVpUbW45cEh3dUFhSXV5cS9DTwpPWnY3KytRMDgzbEozektpUWtrWHcwWEkvOG9TUVFoZlppZzVIa25SOHJLamc3Y0psbjByTk5DNjloTm5sdTJTCnc1Q1MzTUlLOTIza2JzQ3ExSWZXaS90ck1ZWU1Uby9ZTkswY01ELzVjejlKOWZiRTZvMXB6SkwrMEJWbmJ2TXoKYmMyNGdmMFZHaGFxWmdUTkp4Q29PRzZTNXI4ckJLdDM1b1NsaFFJREFRQUJBb0lCQUZmOXJiUk80L0FiU3U1awp0U1pwN2UxcnFaZzFPTmN5YjVmWVlyd2RCR0RVbVdvdjFwcTgrZS9FYlFYdzlSQnZ2ODFpajhSZW1VRWVIT0JlCmdCcW9kdWNwY0g0VDlXazVjMGVzTnFPRUF2Q09KYmtMU0V5RndFTnhQMGZtUjM2Uk5yajB0SzRldHNYZFZ2RVAKRDRBYytuOFo0OWM4UW0yQ1lSWjlXR2JTcmhSS0YzVWtnOWFJMTNtQ0MyOU82OHVFNHB5QlFKTERIV1R0OFJtdAp3ZjAvNmhEdHB5OHVHNHpiR2NpMnBKYlM3VHpieXRmc1JtYVpESG40Zis2VHNYbzgvbHJSU1VTeWdqdGN3UnB4CldTcmJNbm5BNkxEdHA1YzJrRVF1czRGSC9uSThhNE9GWlAxcUhjQ1VmNzh4TklMZnFPbDZFSURuTkpMaXNrZWQKNzJ4MlFlRUNnWUVBdzBCMFBQMmtsM1YwcjZmOHpzTmxPYTAwLzRUanNPY2RpWlhleDFxNGlJUFdCWm9VQ1MrcQp4YWl4S3c4RVo1SVppcExMK0VnVzByVk5adWZVb1BRSGdUL3UzTmNUNWRxOTdLeENOMTVQcm9mK1RpcEt4VEloCkltVWhYMlpEK2QzTEdxbnNqazNjR0tPZmtOWlJBd0VvYXBjTVcraGo5bWlCMVVmdVM5UlJqMk1DZ1lFQXpJWU0KdklXQkV0bXdzUDdhVGtZUk91eDR4b0NCSGR1TG8rMTd1Y01TV01vbkxpWFdVTXIvM1laTzMxQTh3aFJxWVozQwpjR29WZ3hWT1BHcFJUTENqS2pEdjBDdlNDSW9JZDNLSU56ZWRwNUlTeU16UkhXbGhXdnRSbmdudkVkYksxMzFqCmIyeG1xVVNQdE1UWWhQWjZCbXo3M1JzVTd0dDdTbm1tSWZqSmovY0NnWUFNY2NJMjFPKzFtNDNaV0RxYnJ3WjMKbTV1Q0lhVWxkRVdFckdHcmtST3IxOE0vVGlleXdpLy9NeFkvcVZCZGpZbEZOTC85VGhMdVVSSGkyaW5LTEdPQwpFR0lYL3psTWNCbWt5UUhiWjQ1cWtFNWNDd1FDOTRQM0hqejNTSnhTZzVsYlZMTTRDcXhaZ2F3ODNmd0IxZ1FPCmJ4d2hpM2s3amtPZ0pWcUJ5TUYrQXdLQmdDNldHakNXK0YraTFteDZvSjlUdG5rRmhEMHk2RFkwM0FucS9sUEIKNjF2dU1CNkMzOTVuWHdER3B4Q1c1a0FQQm14VjB3Um9KWjVHTEJ2MjI2M3NUajQrQjJJVG1UUDR2UlQ0TWE3aQpMRGNQUHRnZVQwT3p6VWs4RmNzNTJBcm9NaXdEazdLOXJtVEFDVHZUMnIzdXByenY5aTdYREYyY0FPbGw3RUd3CnViamhBb0dCQUl1eVZybWV6cnVZLytXMUpFQTdhV2srcU0xMi9BVTNqTEpCOWpNMXJuZkdjRzhNSElEQVYzS1UKUGE2aDIzeFNsYTloSDVYSHpBbmVNK29iNENSUXZkSlF0cVIreXlySlJ6SjdTOWpjcUlDcUlEOG52Qzlxc05BbQppWFE3VHk1M3FRMDlwK09xRG5iNElMS3VETDlQVGRVaCs3OGJpaS96eENjcVdCWG1teUg2Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
- name: rancher-admin
  user:
    token: "kubeconfig-user-8c6fl.c-zpjp2:qczmnbnmdv5zxrbnfgxg7jpjtcfb6whs4kpkktx8dd8t22r5472g96"

# kubectl config get-contexts
CURRENT   NAME                               CLUSTER              AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes        kubernetes           kubernetes-admin   
          rancher-admin@rancher-production   rancher-production   rancher-admin      
# kubectl config current-context 
kubernetes-admin@kubernetes

# kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
k8s-docker1   Ready    worker          10d   v1.26.2
k8s-docker2   Ready    worker          10d   v1.26.2
k8s-master    Ready    control-plane   10d   v1.26.2

# kubectl config use-context rancher-admin@rancher-production 
Switched to context "rancher-admin@rancher-production".
# kubectl get nodes
NAME       STATUS   ROLES               AGE      VERSION
docker01   Ready    worker              22d      v1.20.10
docker02   Ready    worker              278d     v1.20.10
docker03   Ready    worker              2y180d   v1.20.10
k8s01      Ready    controlplane,etcd   2y180d   v1.20.10
k8s02      Ready    controlplane,etcd   454d     v1.20.10
k8s03      Ready    controlplane,etcd   454d     v1.20.10


```



![image-20230418171638724](考试内容解答截图\image-20230418171638724.png)

### 1. RBCA配置

```
题目：
创建一个名为deployment-clusterrole且仅允许创建以下资源类型的新ClusterRole:
	Deployment
	StatefulSet
	DaemonSet
在现有的namespace app-team1中创建一个名为cicd-token的新ServiceAccount。
限于namespace app-team1，将新的ClusterRole deployment-clusterrole绑定到新的ServiceAccount cicd-token
```

```bash
精简命令：
# kubectl create clusterrole --help
# kubectl create clusterrole deployment-clusterrole --verb=create --resource=deployments,statefulsets,daemonsets --dry-run=client -o yaml > cr.yaml
# cat cr.yaml
# kubectl create -f cr.yaml 

# kubectl create sa cicd-token -n app-team1

# kubectl create rolebinding --help
# kubectl get clusterrole|grep deployment-clusterrole
# kubectl get sa -n app-team1

# kubectl create rolebinding cicd-token-rolebinding --clusterrole=deployment-clusterrole --serviceaccount=app-team1:cicd-token -n app-team1 --dry-run=client -o yaml > rb.yaml
# cat rb.yaml 
# kubectl create -f rb.yaml 

# kubectl get rolebindings.rbac.authorization.k8s.io -n app-team1 

```

```bash
详细命令：
# kubectl create clusterrole --help
Create a cluster role.

Examples:
  # Create a cluster role named "pod-reader" that allows user to perform "get", "watch" and "list" on pods
  kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods
...输出省略...
Usage:
  kubectl create clusterrole NAME --verb=verb --resource=resource.group [--resource-name=resourcename]
[--dry-run=server|client|none] [options]
  
# kubectl create clusterrole deployment-clusterrole --verb=create --resource=deployments,statefulsets,daemonsets --dry-run=client -o yaml > cr.yaml

# cat cr.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deployment-clusterrole
rules:
- apiGroups:
  - apps
  resources:
  - deployments
  - statefulsets
  - daemonsets
  verbs:
  - create

# kubectl create -f cr.yaml 
clusterrole.rbac.authorization.k8s.io/deployment-clusterrole created

考试环境此步省略
# kubectl create namespace app-team1
namespace/app-team1 created

# kubectl create sa cicd-token -n app-team1
serviceaccount/cicd-token created

# kubectl create rolebinding --help
...输出省略...
Usage:
  kubectl create rolebinding NAME --clusterrole=NAME|--role=NAME [--user=username] [--group=groupname]
[--serviceaccount=namespace:serviceaccountname] [--dry-run=server|client|none] [options]

# kubectl get clusterrole|grep deployment-clusterrole
deployment-clusterrole                                                 2023-04-18T08:51:09Z
# kubectl get sa -n app-team1
NAME         SECRETS   AGE
cicd-token   0         11m
default      0         18m

# kubectl create rolebinding cicd-token-rolebinding --clusterrole=deployment-clusterrole --serviceaccount=app-team1:cicd-token -n app-team1 --dry-run=client -o yaml > rb.yaml

# cat rb.yaml 
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  creationTimestamp: null
  name: cicd-token-rolebinding
  namespace: app-team1
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deployment-clusterrole
subjects:
- kind: ServiceAccount
  name: cicd-token
  namespace: app-team1

# kubectl create -f rb.yaml 
rolebinding.rbac.authorization.k8s.io/cicd-token-rolebinding created

# kubectl get rolebindings.rbac.authorization.k8s.io -n app-team1 
NAME                     ROLE                                 AGE
cicd-token-rolebinding   ClusterRole/deployment-clusterrole   9s

# kubectl delete deployment test-busybox -n app-team1

验证权限：
# kubectl -n app-team1 auth can-i create deployments --as system:serviceaccount:app-team1:cicd-token
# kubectl -n app-team1 auth can-i create secrets --as system:serviceaccount:app-team1:cicd-token 
```



### 2. kubectl drain设置

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：
# kubectl config use-context ek8s
# kubectl drain ek8s-node-1 --ignore-daemonsets
```

```bash
详细命令：
# kubectl drain --help
Drain node in preparation for maintenance.
...输出省略...
    --ignore-daemonsets=false:
	Ignore DaemonSet-managed pods.

Usage:
  kubectl drain NODE [options]

# kubectl drain ek8s-node-1 --ignore-daemonsets

# kubectl drain k8s-docker2 --ignore-daemonsets 
node/k8s-docker2 cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/calico-node-q7kn5, kube-system/kube-proxy-p2vws
evicting pod kube-system/coredns-567c556887-mqvtk
evicting pod ingress-nginx/ingress-nginx-controller-68c7fccc8d-m87n6
evicting pod ingress-nginx/ingress-nginx-defaultbackend-6594895459-6nsbv
pod/ingress-nginx-defaultbackend-6594895459-6nsbv evicted
pod/coredns-567c556887-mqvtk evicted
pod/ingress-nginx-controller-68c7fccc8d-m87n6 evicted
node/k8s-docker2 drained
# kubectl get nodes
NAME          STATUS                     ROLES           AGE   VERSION
k8s-docker1   Ready                      worker          11d   v1.26.2
k8s-docker2   Ready,SchedulingDisabled   worker          11d   v1.26.2
k8s-master    Ready                      control-plane   11d   v1.26.2

# kubectl uncordon k8s-docker2
node/k8s-docker2 uncordoned
# kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
k8s-docker1   Ready    worker          11d   v1.26.2
k8s-docker2   Ready    worker          11d   v1.26.2
k8s-master    Ready    control-plane   11d   v1.26.2

# kubectl  drain node k8s-docker2
Error from server (NotFound): nodes "node" not found
# kubectl  drain  k8s-docker2
node/k8s-docker2 cordoned
error: unable to drain node "k8s-docker2" due to error:cannot delete DaemonSet-managed Pods (use --ignore-daemonsets to ignore): kube-system/calico-node-q7kn5, kube-system/kube-proxy-p2vws, continuing command...
There are pending nodes to be drained:
 k8s-docker2
cannot delete DaemonSet-managed Pods (use --ignore-daemonsets to ignore): kube-system/calico-node-q7kn5, kube-system/kube-proxy-p2vws
```



### 3. kubeadm等升级

```
题目：
Given an existing kubernetes cluster running version 1.26.3, upgrade all of the kubernetes control plain and node components on the master node only to version 1.26.4.
you are also expected to upgrade kubelet and kubectl on the master node 

tips: Be sure to drain the master node before upgrading it and uncordon it after the upgrade.
Do not upgrade the worker nodes,etcd,the container manager,the CNI plugin, the DNS service or any other addons.

```

```bash
精简命令：
# kubectl drain k8s-master --ingore-daemonsets

# apt update -y

# apt-cache madison kubeadm|more

# apt-mark unhold kubeadm && \
 apt-get update && apt-get install -y kubeadm=1.26.4-00 && \
 apt-mark hold kubeadm

# kubeadm version

# kubeadm upgrade plan

# kubeadm upgrade apply v1.26.4 --etcd-upgrade=false

# apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.26.4-00 kubectl=1.26.4-00 && \
apt-mark hold kubelet kubectl

# sudo systemctl daemon-reload
# sudo systemctl retart kubelet

# kubectl uncordon k8s-master

# kubectl get nodes
```
```bash
精简命令参考命令：
# kubectl drain k8s-master --ingore-daemonsets

# apt update -y

# apt-cache madison kubeadm|more

# apt upgrade kubeadm=1.26.4-00 kubelet=1.26.4-00 kubectl=1.26.4-00 -y

# kubeadm version

# kubeadm upgrade plan

# kubeadm upgrade apply v1.26.4 --etcd-upgrade=false

# kubectl uncordon k8s-master

# kubectl get nodes

```


```bash

```

```bash
详细命令参考命令：
# kubectl drain k8s-master --ignore-daemonsets 
node/k8s-master already cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/calico-node-w5xph, kube-system/kube-proxy-zmzxx
evicting pod kube-system/coredns-567c556887-jw55m
pod/coredns-567c556887-jw55m evicted
node/k8s-master drained
# kubectl get nodes
NAME          STATUS                     ROLES           AGE   VERSION
k8s-docker1   Ready                      worker          11d   v1.26.2
k8s-docker2   Ready                      worker          11d   v1.26.2
k8s-master    Ready,SchedulingDisabled   control-plane   11d   v1.26.2
# kubectl get pod -A -owide|grep k8s-master
kube-system     calico-node-w5xph                               1/1     Running   1 (4d12h ago)   11d     192.168.1.234   k8s-master    <none>           <none>
kube-system     etcd-k8s-master                                 1/1     Running   1 (4d12h ago)   11d     192.168.1.234   k8s-master    <none>           <none>
kube-system     kube-apiserver-k8s-master                       1/1     Running   1 (4d12h ago)   11d     192.168.1.234   k8s-master    <none>           <none>
kube-system     kube-controller-manager-k8s-master              1/1     Running   4 (4d11h ago)   11d     192.168.1.234   k8s-master    <none>           <none>
kube-system     kube-proxy-zmzxx                                1/1     Running   1 (4d12h ago)   11d     192.168.1.234   k8s-master    <none>           <none>
kube-system     kube-scheduler-k8s-master                       1/1     Running   4 (4d11h ago)   11d     192.168.1.234   k8s-master    <none>           <none>

# apt update -y
...输出省略...

# apt-cache madison kubeadm|more
   kubeadm |  1.27.1-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.27.0-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.26.4-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.26.3-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.26.2-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.26.1-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.26.0-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages

# dpkg -l |grep kubeadm
ii  kubeadm                               1.26.2-00                         amd64        Kubernetes Cluster Bootstrapping Tool
root@k8s-master:~# dpkg -l |grep kubelet
ii  kubelet                               1.26.2-00                         amd64        Kubernetes Node Agent
root@k8s-master:~# dpkg -l |grep kubectl
ii  kubectl                               1.26.2-00                         amd64        Kubernetes Command Line Tool

# apt-mark unhold kubeadm && \
 apt-get update && apt-get install -y kubeadm=1.26.4-00 && \
 apt-mark hold kubeadm

...输出省略...

# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"26", GitVersion:"v1.26.4", GitCommit:"f89670c3aa4059d6999cb42e23ccb4f0b9a03979", GitTreeState:"clean", BuildDate:"2023-04-12T12:12:17Z", GoVersion:"go1.19.8", Compiler:"gc", Platform:"linux/amd64"}

# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.26.0
[upgrade/versions] kubeadm version: v1.26.4
I0419 04:28:51.492828 2337005 version.go:256] remote version is much newer: v1.27.1; falling back to: stable-1.26
[upgrade/versions] Target version: v1.26.4
[upgrade/versions] Latest version in the v1.26 series: v1.26.4

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       TARGET
kubelet     2 x v1.26.2   v1.26.4
            1 x v1.26.4   v1.26.4

Upgrade to the latest version in the v1.26 series:

COMPONENT                 CURRENT   TARGET
kube-apiserver            v1.26.0   v1.26.4
kube-controller-manager   v1.26.0   v1.26.4
kube-scheduler            v1.26.0   v1.26.4
kube-proxy                v1.26.0   v1.26.4
CoreDNS                   v1.9.3    v1.9.3
etcd                      3.5.6-0   3.5.6-0

You can now apply the upgrade by executing the following command:

        kubeadm upgrade apply v1.26.4

_____________________________________________________________________


The table below shows the current state of component configs as understood by this version of kubeadm.
Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
upgrade to is denoted in the "PREFERRED VERSION" column.

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________

# kubeadm upgrade apply v1.26.4 --etcd-upgrade=false
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.26.4"
[upgrade/versions] Cluster version: v1.26.0
[upgrade/versions] kubeadm version: v1.26.4
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.26.4" (timeout: 5m0s)...
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests3284289549"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Renewing apiserver-etcd-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-04-19-04-33-23/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-04-19-04-33-23/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-04-19-04-33-23/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.26.4". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.

# apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.26.4-00 kubectl=1.26.4-00 && \
apt-mark hold kubelet kubectl

# sudo systemctl daemon-reload
# sudo systemctl retart kubelet

# kubectl get nodes
NAME          STATUS                     ROLES           AGE   VERSION
k8s-docker1   Ready                      worker          11d   v1.26.2
k8s-docker2   Ready                      worker          11d   v1.26.2
k8s-master    Ready,SchedulingDisabled   control-plane   11d   v1.26.4

# kubectl uncordon k8s-master 
node/k8s-master uncordoned

# kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
k8s-docker1   Ready    worker          11d   v1.26.2
k8s-docker2   Ready    worker          11d   v1.26.2
k8s-master    Ready    control-plane   11d   v1.26.4

如果coredns发生了镜像变化，那么必须回滚
# kubectl -n kube-system edit deployment coredns
```

```bash
参考命令：
kubectl  drain cka01 --ignore-daemonsets

apt update -y 

apt-cache madison kubeadm

apt upgrade kubeadm=1.21.0-00 kubelet=1.21.0-00 kubectl=1.21.0-00 -y 


kubeadm version

kubeadm upgrade plan
kubeadm upgrade apply v1.21.0 --etcd-upgrade=false

###
###[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.20.2". Enjoy!

###[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
###
# 回退coredns
coredns:v1.8 --> coredns:1.7.0

kubectl uncordon cka01

```




### 4. etcd备份


```
题目：
首先，为运行在https://127.0.0.1:2379上的现有etcd实例创建快照并将快照保存至/data/bucket/etcd-snapshot.db
然后还原位于/srv/data/etcd-snaphot-previous.db的现有先前快照

提示： 为给定实例创建快照预计在几秒内完成。如果该操作似乎挂起，则命令可能有问题。用ctrl+c来取消操作，然后重试。

提供了以下TLS证书和密钥，以通过etcdctl连接到服务器
	CA证书：/opt/KUIN00601/ca.crt
	客户端证书： /opt/KUIN00601/etcd-client.crt
	客户端密钥：/opt/KUIN00601/etcd-client.key
```

```bash
精简命令：
# apt install etcd-client -y
# export ETCDCTL_API=3
# etcdctl -h
备份：
# etcdctl --endpoint=127.0.0.1:2379 --cacert=/opt/KUIN00601/ca.crt --crt=/opt/KUIN00601/etcd-client.crt --key=/opt/KUIN00601/etcd-client.key snapshot save /data/bucket/etcd-snapshot.db

在恢复数据之前，需要停止使用和写入新数据
# mv /etc/kubernetes/manifests /etc/kubernetes/manifests.bak
# mv /var/lib/etcd /var/lib/etcd.bak

还原：
# etcdctl --endpoint=127.0.0.1:2379 --cacert=/opt/KUIN00601/ca.crt --crt=/opt/KUIN00601/etcd-client.crt --key=/opt/KUIN00601/etcd-client.key --data-dir=/var/lib/etcd snapshot restore /srv/data/etcd-snaphot-previous.db

恢复服务：
# mv /etc/kubernetes/manifests.bak /etc/kubernetes/manifests
# systemctl restart kubelet.service

```

```bash
详细命令：
# apt install etcd-client -y
# etcdctl -h

# export ETCDCTL_API=3
# etcdctl -h

# cd /etc/kubernetes/pki/etcd
# ls
ca.crt  ca.key  healthcheck-client.crt  healthcheck-client.key  peer.crt  peer.key  server.crt  server.key

备份：
# export ETCDCTL_API=3
# etcdctl --endpoints=127.0.0.1:2379 --cacert=./ca.crt --cert=./server.crt --key=./server.key member list
5bcec1d5b14a78aa, started, k8s-master, https://192.168.1.234:2380, https://192.168.1.234:2379

# etcdctl --endpoints=127.0.0.1:2379 --cacert=./ca.crt --cert=./server.crt --key=./server.key endpoint health
127.0.0.1:2379 is healthy: successfully committed proposal: took = 1.427836ms
# etcdctl --endpoints=127.0.0.1:2379 --cacert=./ca.crt --cert=./server.crt --key=./server.key endpoint status
127.0.0.1:2379, 5bcec1d5b14a78aa, 3.5.6, 3.9 MB, true, 4, 16876

# etcdctl snapshot save --help
NAME:
        snapshot save - Stores an etcd node backend snapshot to a given file

USAGE:
        etcdctl snapshot save <filename> [flags]

OPTIONS:
  -h, --help[=false]    help for save

GLOBAL OPTIONS:
      --cacert=""                               verify certificates of TLS-enabled secure servers using this CA bundle
      --cert=""                                 identify secure client using this TLS certificate file
      --command-timeout=5s                      timeout for short running command (excluding dial timeout)
      --debug[=false]                           enable client-side debug logging
      --dial-timeout=2s                         dial timeout for client connections
      --endpoints=[127.0.0.1:2379]              gRPC endpoints
      --hex[=false]                             print byte strings as hex encoded strings
      --insecure-skip-tls-verify[=false]        skip server certificate verification
      --insecure-transport[=true]               disable transport security for client connections
      --key=""                                  identify secure client using this TLS key file
      --user=""                                 username[:password] for authentication (prompt if password is not supplied)
  -w, --write-out="simple"                      set the output format (fields, json, protobuf, simple, table)

# etcdctl --endpoints=127.0.0.1:2379 --cacert=./ca.crt --cert=./server.crt --key=./server.key snapshot save /opt/20240101.db
Snapshot saved at /opt/20240101.db
# etcdctl --endpoints=127.0.0.1:2379 --cacert=./ca.crt --cert=./server.crt --key=./server.key snapshot status /opt/20240101.db 
886e9ef5, 15012, 1296, 3.9 MB

还原：
先停止服务
mv /etc/kubernetes/manifests /etc/kubernetes/manifests.bak
sleep 1m

删除现有etcd
mv /var/lib/etcd /var/lib/etc.bak

还原失败：
# cd /etc/kubernetes/pki/etcd
# etcdctl --endpoints=127.0.0.1:2379 --cacert=./ca.crt --cert=./server.crt --key=./server.key --data-dir /var/lib/etcd snapshot restor /opt/20240101.db 
Error:  expected sha256 [28 142 48 141 16 190 99 86 3 46 154 184 142 55 192 47 28 62 173 32 210 100 223 224 76 194 65 100 104 68 127 98], got [130 19 195 169 66 122 173 207 13 187 125 208 48 178 95 162 160 58 90 1 160 243 47 144 15 43 185 145 105 206 174 36]

加参数，还原成功：
# rm -rfv /var/lib/etcd
# etcdctl --endpoints=127.0.0.1:2379 --cacert=ca.crt --cert=server.crt --key=server.key --data-dir /var/lib/etcd snapshot restore /opt/20240101.db --skip-hash-check=true
2023-04-20 07:07:14.614360 I | mvcc: restore compact to 14168
2023-04-20 07:07:14.623310 I | etcdserver/membership: added member 8e9e05c52164694d [http://localhost:2380] to cluster cdf818194e3a8c32

# systemctl restart kubelet 

# etcdctl snapshot restore --help
NAME:
        snapshot restore - Restores an etcd member snapshot to an etcd directory

USAGE:
        etcdctl snapshot restore <filename> [options] [flags]

OPTIONS:
      --data-dir=""                                             Path to the data directory
  -h, --help[=false]                                            help for restore
      --initial-advertise-peer-urls="http://localhost:2380"     List of this member's peer URLs to advertise to the rest of the cluster
      --initial-cluster="default=http://localhost:2380"         Initial cluster configuration for restore bootstrap
      --initial-cluster-token="etcd-cluster"                    Initial cluster token for the etcd cluster during restore bootstrap
      --name="default"                                          Human-readable name for this member
      --skip-hash-check[=false]                                 Ignore snapshot integrity hash value (required if copied from data directory)

GLOBAL OPTIONS:
      --cacert=""                               verify certificates of TLS-enabled secure servers using this CA bundle
      --cert=""                                 identify secure client using this TLS certificate file
      --command-timeout=5s                      timeout for short running command (excluding dial timeout)
      --debug[=false]                           enable client-side debug logging
      --dial-timeout=2s                         dial timeout for client connections
      --endpoints=[127.0.0.1:2379]              gRPC endpoints
      --hex[=false]                             print byte strings as hex encoded strings
      --insecure-skip-tls-verify[=false]        skip server certificate verification
      --insecure-transport[=true]               disable transport security for client connections
      --key=""                                  identify secure client using this TLS key file
      --user=""                                 username[:password] for authentication (prompt if password is not supplied)
  -w, --write-out="simple"                      set the output format (fields, json, protobuf, simple, table)

```

```bash
参考命令：
export ETCDCTL_API=3

etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/opt/KUIN00601/ca.crt --cert=/opt/KUIN00601/etcd-client.crt --key=/opt/KUIN00601/etcd-client.key snapshot save /data/backup/etcd-snapshot.db


# etcdctl snapshot restore /data/backup/etcd-snapshot.db
# rm -rf default.etcd 


etcdctl snapshot restore /srv/data/etcd-snapshot-previous.db

sudo systemctl stop etcd

# owner: etcd
ll /var/lib/etcd -d

mv /var/lib/etcd /tmp/etcd.bak

mv ~/default.etcd /var/lib/etcd
chown etcd.etcd -R /var/lib/etcd

sudo systemctl start etcd 
```





### 5.  NetworkPolicy设置

```
题目：
创建一个名为allow-port-from-namespace的新NetworkPolicy，以允许现有namespace internal中的Pods连接到同一namespace中其他Pods的端口8080。
确保新的NetworkPolicy：
	不允许对没有在监听端口8080的pods的访问
	不允许不来自namespace internal的pods的访问

```

```bash
精简命令：

```

```bash
参考命令：
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-port-from-namespace
  namespace: internal
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
    - protocol: UDP
      port: 8080
  egress:
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
    - protocol: UDP
      port: 8080

kubectl create ns internal
kubectl apply -f allow-port-from-namespace.yaml

```

```bash
详细命令：
# kubectl explain NetworkPolicy.spec
KIND:     NetworkPolicy
VERSION:  networking.k8s.io/v1
...输出省略...
FIELDS:
   egress	<[]Object>
     List of egress rules to be applied to the selected pods. Outgoing traffic
     is allowed if there are no NetworkPolicies selecting the pod (and cluster
     policy otherwise allows the traffic), OR if the traffic matches at least
     one egress rule across all of the NetworkPolicy objects whose podSelector
     matches the pod. If this field is empty then this NetworkPolicy limits all
     outgoing traffic (and serves solely to ensure that the pods it selects are
     isolated by default). This field is beta-level in 1.8

   ingress	<[]Object>
     List of ingress rules to be applied to the selected pods. Traffic is
     allowed to a pod if there are no NetworkPolicies selecting the pod (and
     cluster policy otherwise allows the traffic), OR if the traffic source is
     the pod's local node, OR if the traffic matches at least one ingress rule
     across all of the NetworkPolicy objects whose podSelector matches the pod.
     If this field is empty then this NetworkPolicy does not allow any traffic
     (and serves solely to ensure that the pods it selects are isolated by
     default)

   podSelector	<Object> -required-
     Selects the pods to which this NetworkPolicy object applies. The array of
     ingress rules is applied to any pods selected by this field. Multiple
     network policies can select the same set of pods. In this case, the ingress
     rules for each are combined additively. This field is NOT optional and
     follows standard label selector semantics. An empty podSelector matches all
     pods in this namespace.

   policyTypes	<[]string>
     List of rule types that the NetworkPolicy relates to. Valid options are
     ["Ingress"], ["Egress"], or ["Ingress", "Egress"]. If this field is not
     specified, it will default based on the existence of Ingress or Egress
     rules; policies that contain an Egress section are assumed to affect
     Egress, and all policies (whether or not they contain an Ingress section)
     are assumed to affect Ingress. If you want to write an egress-only policy,
     you must explicitly specify policyTypes [ "Egress" ]. Likewise, if you want
     to write a policy that specifies that no egress is allowed, you must
     specify a policyTypes value that include "Egress" (since such a policy
     would not include an Egress section and would otherwise default to just [
     "Ingress" ]). This field is beta-level in 1.8

# kubectl explain NetworkPolicy.spec.ingress
# kubectl explain NetworkPolicy.spec.ingress.from
# kubectl explain NetworkPolicy.spec.ingress.ports


#np.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-port-from-namespace
  namespace: internal
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
    - protocol: UDP
      port: 8080
  egress:
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
    - protocol: UDP
      port: 8080

# kubectl create ns internal
namespace/internal created

# kubectl create -f np.yaml 
networkpolicy.networking.k8s.io/allow-port-from-namespace created

# kubectl -n internal get networkpolicy
NAME                        POD-SELECTOR   AGE
allow-port-from-namespace   <none>         43s

# kubectl -n internal describe networkpolicies allow-port-from-namespace 
Name:         allow-port-from-namespace
Namespace:    internal
Created on:   2023-04-18 09:51:04 +0000 UTC
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
  Allowing ingress traffic:
    To Port: 8080/TCP
    To Port: 8080/UDP
    From:
      PodSelector: <none>
  Allowing egress traffic:
    To Port: 8080/TCP
    To Port: 8080/UDP
    To:
      PodSelector: <none>
  Policy Types: Ingress, Egress
  
# kubectl -n internal create deployment tomcat --image=tomcat 

# kubectl -n internal create deployment redis --image=redis 

# kubectl -n internal create deployment busybox --image=busybox

# kubectl -n default create deployment tomcat --image=tomcat 

# kubectl -n internal  exec -it busybox-xxx-xxx -- /bin/sh
  telnet tomcatPodIP 8080
  telnet redisPodIP 6379
  
# kubectl -n default  exec -it busybox-xxx-xxx -- /bin/sh
  telnet tomcatPodIP 8080
  telnet redisPodIP 6379
```


### 5.1.  NetworkPolicy设置01


![image-20230418175336197](考试内容解答截图\image-20230418175336197.png)

```bash
精简命令：

```

```bash
参考命令：
# kubectl create ns echo
namespace/echo created
# kubectl label ns echo project=myproject
namespace/echo labeled

# kubectl get ns --show-labels |grep echo
echo              Active   92s    kubernetes.io/metadata.name=echo,project=myproject
# kubectl get ns --show-labels |grep myproject
echo              Active   108s   kubernetes.io/metadata.name=echo,project=myproject

#np01.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-port-from-namespace01
  namespace: internal
spec:
  podSelector: {}
  policyTypes:
    - Egress
  eress:
    - to:
        - ipBlock:
            cidr: 172.17.0.0/16
            except:
              - 172.17.1.0/24
        - namespaceSelector:
            matchLabels:
              project: myproject
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 9000
        - protocol: UDP
          port: 9000
          
# kubectl create -f np01.yaml 
networkpolicy.networking.k8s.io/allow-port-from-namespace01 created
# kubectl -n internal get networkpolicy
NAME                          POD-SELECTOR   AGE
allow-port-from-namespace     <none>         14m
allow-port-from-namespace01   <none>         19s

# kubectl -n internal describe networkpolicy allow-port-from-namespace01 
Name:         allow-port-from-namespace01
Namespace:    internal
Created on:   2023-04-18 10:05:08 +0000 UTC
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
  Not affecting ingress traffic
  Allowing egress traffic:
    To Port: 9000/TCP
    To Port: 9000/UDP
    To:
      IPBlock:
        CIDR: 172.17.0.0/16
        Except: 172.17.1.0/24
    To:
      NamespaceSelector: project=myproject
    To:
      PodSelector: <none>
  Policy Types: Egress

```

```bash
详细命令：

```




### 6. deployment/svc配置

```
题目：
Reconfigure the existing deployment front-end and add a port specification named http exposing port 80/tcp of existing container nginx.
Create a new service named front-end-svc exposing the container port http.
Configure the new service to also expose the individual Pods via a NodePort on the nodes on which they are scheduled

```

```bash
精简命令：

```

```bash
详细命令：
---
# 原始dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: front-end
  labels:
    app: front-end
spec:
  replicas: 1
  selector:
    matchLabels:
      app: front-end
  template:
    metadata:
      labels:
        app: front-end
    spec:
      containers:
      - name: nginx
        image: nginx

---
# 修改后dp01.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: front-end
  labels:
    app: front-end
spec:
  replicas: 1
  selector:
    matchLabels:
      app: front-end
  template:
    metadata:
      labels:
        app: front-end
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - name: http
          protocol: TCP
          containerPort: 80
---
# front-end-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: front-end-svc
  labels:
    app: front-end-svc
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
    
# kubectl edit deployments.apps front-end 
添加：
        ports:
        - name: http
          protocol: TCP
          containerPort: 80

deployment.apps/front-end edited

# kubectl create -f front-end-svc.yaml 
service/front-end-svc created
# kubectl get svc
NAME            TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
front-end-svc   NodePort   10.98.24.28   <none>        80:32063/TCP   6s

或者直接用kubectl expose命令：
# kubectl expose deployment --help
...输出省略...
Usage:
  kubectl expose (-f FILENAME | TYPE NAME) [--port=port] [--protocol=TCP|UDP|SCTP] [--target-port=number-or-name]
[--name=name] [--external-ip=external-ip-of-service] [--type=type] [options]

# kubectl expose deployment front-end --name=front-end-svc --port=80 --protocol=TCP --target-port=80 --type=NodePort
```




### 7. ingress配置

```
题目：
Create a new nginx ingress resource as follows:
	Name: ping 
	Namespace: ing-internal
	Exposing service hi on path /hi using service port 5678

tips: The availability of service hi can be checked using the following commands,which should retun hi: 
curl -KL <INTERNAL_IP>/hi

```

```bash
精简命令：
# kubectl get ingressclass

---
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ping
  namespace: ing-internal
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /hi
        pathType: Prefix
        backend:
          service:
            name: hi
            port:
              number: 5678

# kubectl create -f ingress.yaml
```

```bash
详细命令：
# config environment

kubectl create ns ing-internal

kubectl run hi --image=registry.cn-zhangjiakou.aliyuncs.com/breezey/ping -n ing-internal

kubectl expose pod hi --port=5678 -n ing-internal

kubectl -n ing-internal get svc
NAME   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
hi     ClusterIP   10.111.223.202   <none>        5678/TCP   99s

curl 10.111.223.202:5678/hi
hi

解析：
# kubectl get ingressclass
nginx   k8s.io/ingress-nginx   <none>       4d23h

# kubectl create ingress 
...输出省略...
Usage:
  kubectl create ingress NAME --rule=host/path=service:port[,tls[=secret]]  [options]

Use "kubectl options" for a list of global command-line options (applies to all commands).

# kubectl -n ing-internal create ingress ping --rule=/hi=hi:5678 -o yaml --dry-run=client
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ping
  namespace: ing-internal
spec:
  rules:
  - http:
      paths:
      - backend:
          service:
            name: hi
            port:
              number: 5678
        path: /hi
        pathType: Exact
 
根据kubectl create ingress或网址yaml修改：
---
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ping
  namespace: ing-internal
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /hi
        pathType: Prefix
        backend:
          service:
            name: hi
            port:
              number: 5678

# kubectl create -f ingress.yaml
ingress.networking.k8s.io/ping created
# kubectl -n ing-internal get ingress
NAME   CLASS   HOSTS   ADDRESS   PORTS   AGE
ping   nginx   *                 80      41s

网址模板：
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx-example
  rules:
  - http:
      paths:
      - path: /testpath
        pathType: Prefix
        backend:
          service:
            name: test
            port:
              number: 80
```




### 8. deployment的扩缩容配置
```
题目：
Scale the deploy persentation to 3 pods
```

```bash
精简命令：
# kubectl get deployments.apps presentation
```

```bash
详细命令：
config env
# kubectl create deploy presentation --image=busybox -- sleep 3600

answer
# kubectl get deployments.apps presentation
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
presentation   1/1     1            1           38s

# kubectl scale deployment presentation --replicas=3
deployment.apps/presentation scaled

# kubectl get deployments.apps presentation 
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
presentation   1/3     3            1           69s

# kubectl get deployments.apps presentation 
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
presentation   3/3     3            3           97s



Scale the deploy persentation to 3 pods and record it
# kubectl scale deployment presentation --replicas=3 --record=true
Flag --record has been deprecated, --record will be removed in the future
deployment.apps/abc scaled
```





### 9. nodeSelector及scheduler配置

```
题目：
Schedule a pod as follows:
	Name: nginx-kusc00401
	Image: nginx
	Node selector: disk=spinning
```

```bash
精简命令：
# kubectl get nodes --show-labels
# kubectl run nginx-kusc00401 --image=nginx --dry-run=client -o yaml > kusc.yaml
在containers一行的上面添加：
  nodeSelector:
    disk: spinning
    
# kubectl apply -f kusc.yaml
# kubectl get pod |grep nginx-kusc00401
```

```bash
详细命令：
config env
# kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
k8s-docker1   Ready    worker          11d   v1.26.2
k8s-docker2   Ready    worker          11d   v1.26.2
k8s-master    Ready    control-plane   11d   v1.26.4

# kubectl label node k8s-docker2 disk=spinning
node/k8s-docker2 labeled


answer

# kubectl get nodes --show-labels

# kubectl run --help
Usage:
  kubectl run NAME --image=image [--env="key=value"] [--port=port] [--dry-run=server|client] [--overrides=inline-json]
[--command] -- [COMMAND] [args...] [options]

# kubectl run nginx-kusc00401 --image=nginx --dry-run=client -o yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: nginx-kusc00401
  name: nginx-kusc00401
spec:
  containers:
  - image: nginx
    name: nginx-kusc00401
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

添加nodeSelector一项进行修改：
---
# ns-01.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx-kusc00401
  name: nginx-kusc00401
spec:
  nodeSelector:
    disk: spinning
  containers:
  - image: nginx
    name: nginx-kusc00401
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  
# kubectl apply -f ns-01.yaml 
pod/nginx-kusc00401 created  
```




### 10. kubectl describe过滤Taints

```
题目：
Check to see how many nodes are ready(not including nodes tainted NoSchedule) and write the number to /opt/KUSCoo402/kusc00402.txt.
```

```bash
精简命令：
# for i in `kubectl get nodes|grep -v NAME|grep Ready|awk '{print $1}'`; do kubectl describe nodes $i |grep Taints|grep "<none>"; done| wc -l

echo 1 > /opt/KUSCoo402/kusc00402.txt

或者：
先看Ready的node
# kubectl get nodes
再过滤taints
# kubectl describe nodes |grep -i taints
```

```bash
详细命令：
config evn
# kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
k8s-docker1   Ready    worker          11d   v1.26.2
k8s-docker2   Ready    worker          11d   v1.26.2
k8s-master    Ready    control-plane   11d   v1.26.4
# kubectl taint node k8s-docker2 unuse=tmp:NoSchedule
node/k8s-docker2 tainted
# kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
k8s-docker1   Ready    worker          11d   v1.26.2
k8s-docker2   Ready    worker          11d   v1.26.2
k8s-master    Ready    control-plane   11d   v1.26.4

# kubectl describe nodes k8s-docker2|grep -i taints
Taints:             unuse=tmp:NoSchedule
# kubectl describe nodes k8s-docker1|grep -i taints
Taints:             <none>
# kubectl describe nodes k8s-master|grep -i taints
Taints:             node-role.kubernetes.io/control-plane:NoSchedule

answer

# for i in `kubectl get nodes|grep -v NAME|grep Ready|awk '{print $1}'`; do kubectl describe nodes $i |grep Taints|grep "<none>"; done
Taints:             <none>

# for i in `kubectl get nodes|grep -v NAME|grep Ready|awk '{print $1}'`; do kubectl describe nodes $i |grep Taints|grep "<none>"; done| wc -l
1

# echo 1 > /opt/KUSCoo402/kusc00402.txt
```

```bash
参考配置：
for i in `kubectl get nodes  | awk '$2 ~/^Ready/{print $1}'`;do kubectl describe node $i |grep Taints |grep "<none>";done | wc -l

echo 1 > /opt/KUSCoo402/kusc00402.txt


# kubectl describe node | grep -i taints|grep -v -i -e noschedule -e unreachable | wc -l
1
```



### 11. pod多容器配置

```
题目：
Create a pod named kucc8 with a single app container for each of the following images running inside(there may be between 1 and 4 images specified):
nginx + redis + memcached + consul
```

```bash
精简命令：
# kubectl run --help
# kubectl run kucc8 --image=nginx --dry-run=client -o yaml > kucc8.yaml
修改yaml添加:
  - image: redis
    name: redis
  - image: memcached 
    name: memcached
  - image: consul
    name: consul
# kubectl create -f ./kucc8.yaml 
```

```bash
详细命令：
# kubectl run --help
...输出省略...
Usage:
  kubectl run NAME --image=image [--env="key=value"] [--port=port] [--dry-run=server|client] [--overrides=inline-json]
[--command] -- [COMMAND] [args...] [options]

# kubectl run kucc8 --image=nginx --dry-run=client -o yaml > kucc8.yaml
# vi kucc8.yaml 
# cat kucc8.yaml 
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: kucc8
  name: kucc8
spec:
  containers:
  - image: nginx
    name: kucc8
  - image: redis
    name: redis
  - image: memcached 
    name: memcached
  - image: consul
    name: consul
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always

# kubectl create -f ./kucc8.yaml 
pod/kucc8 created
```




### 12. pv配置

```
题目：
Create a persistent volume with name app-config, of capacity 1Gi and access mode ReadOnlyMany. The type of volume is hostPath and its location is /srv/app-config.
```

```bash
精简命令：

```

```bash
详细命令：
# kubectl explain pv.spec
---
# pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: app-config
spec:
  capacity:
    storage: 1G
  accessModes:
    - ReadOnlyMany
  hostPath:
    path: /srv/app-config
---

# kubectl apply -f pv.yaml 
persistentvolume/app-config created
# kubectl get pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                         STORAGECLASS   REASON   AGE
app-config   1G         ROX            Retain           Available                                                         3s
```


### 13. pvc及volumeMounts/volumes配置

```
题目：
Create a new PersistentVolumeClaim:
	Name: pv-volume
	Class: csi-hostpath-sc
	Capacity: 10Mi
Create a new Pod which mounts the PersistentVolumeClaim as a volume:
	Name: web-server
	Image: nginx
	Mount path: /usr/share/nginx/html
Configure the new Pod to have ReadWriteOnce access on the volume.
Finally, using kubectl edit or kubectl patch expand the PersistentVolumeClaim to a capacity of 70Mi and record that change

```

```bash
精简命令：
# kubectl explain pvc.spec
# kubectl run web-server --image=nginx --dry-run=client -o yaml > web-server.yaml

---
# web-server.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume
spec:
  accessModes: 
    - ReadWriteOnce
  storageClassName: csi-hostpath-sc
  resources:
    requests:
      storage: 10Mi
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: web-server
  name: web-server
spec:
  containers:
  - image: nginx
    name: web-server
    resources: {}
    volumeMounts:
    - name: pv-volume
      mountPath: /usr/share/nginx/html
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  volumes:
  - name: pv-volume
    persistentVolumeClaim:
      claimName: pv-volume
```

```bash
详细命令：
config env:
安装nfs-kernel-server及存储类csi-hostpath-sc

answer:

# kubectl explain pvc.spec
# kubectl run web-server --image=nginx --dry-run=client -o yaml > web-server.yaml

---
# web-server.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume
spec:
  accessModes: 
    - ReadWriteOnce
  storageClassName: csi-hostpath-sc
  resources:
    requests:
      storage: 10Mi
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: web-server
  name: web-server
spec:
  containers:
  - image: nginx
    name: web-server
    resources: {}
    volumeMounts:
    - name: pv-volume
      mountPath: /usr/share/nginx/html
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  volumes:
  - name: pv-volume
    persistentVolumeClaim:
      claimName: pv-volume
      
# kubectl apply -f web-server.yaml

确认存储类是否允许扩容，注意下面的ALLOWVOLUMEEXPANSION参数是否为true
# kubectl get storageclass
NAME                        PROVISIONER         RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
csi-hostpath-sc (default)   cnlxh/nfs-storage   Delete          Immediate           true                   18h


修改为70Mi
# kubectl edit pvc pv-volume --record=true
```



### 14. kubectl logs

```
疑问：
kubectl logs bar |grep unable-to-access-website > /opt/KUTR00101/bar
kubectl logs -f bar |grep unable-to-access-website > /opt/KUTR00101/bar
```



```
题目：
Monitor the logs of pod bar and:
	Extract log lines corresponding to error unable-to-access-website
	Write them to /opt/KUTR00101/bar
```

```bash
精简命令：
# kubectl logs bar|grep unable-to-access-website > /opt/KUTR00101/bar
# cat /opt/KUTR00101/bar
```

```bash
详细命令：
config env:
# kubectl run bar --image=registry.cn-zhangjiakou.aliyuncs.com/breezey/bar
# mkdir /opt/KUTR00101
# touch /opt/KUTR00101/bar

answer:
# kubectl get pod bar
NAME   READY   STATUS    RESTARTS   AGE
bar    1/1     Running   0          72s

# kubectl logs bar|grep unable-to-access-website > /opt/KUTR00101/bar
# cat /opt/KUTR00101/bar
```

### 15. 一个pod多个容器，sidecar，共享volume

```
题目：
Add a busybox sidecar container to the existing Pod big-corp-app.The new sidecar container has to run the following command: 
/bin/sh -c tail -n+1 /var/log/big-corp-app.log

Use a volume mount named logs to make the file /var/log/big-corp-app.log available to the sidecar container

warn: Don't modify the existing container. Don't modify the path of the log file. both containers must access it at /var/log/big-corp-app.log

```

```bash
精简命令：

```

```bash
详细命令：
config env:
# kubectl run  big-corp-app --image=registry.cn-zhangjiakou.aliyuncs.com/breezey/bar 

# answer

# kubectl get pod big-corp-app -o yaml > big-corp-app.yaml
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: big-corp-app
  name: big-corp-app
  namespace: default
spec:
  containers:
  - image: registry.cn-zhangjiakou.aliyuncs.com/breezey/bar
    imagePullPolicy: Always
    name: big-corp-app
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-wz9kd
      readOnly: true
    - mountPath: /var/log
      name: logs
  - name: busybox
    image: busybox
    command:
    - /bin/sh 
    - -c 
    - "tail -n+1 /var/log/big-corp-app.log"
    volumeMounts:
    - mountPath: /var/log
      name: logs
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  nodeName: k8s-docker1
  preemptionPolicy: PreemptLowerPriority
  priority: 0
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext: {}
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
  tolerations:
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
  volumes:
  - name: logs
    emptyDir: {}
  - name: kube-api-access-wz9kd
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          items:
          - key: ca.crt
            path: ca.crt
          name: kube-root-ca.crt
      - downwardAPI:
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
            path: namespace
---
pod不支持直接修改，确认没问题之后，直接删除原有pod并重建
# kubectl delete pod big-core-app

# kubectl apply -f big-core-app.yaml 
pod/big-corp-app created

# kubectl logs big-core-app busybox
```

```bash
参考答案：
# answer
# big-corp-app.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: big-corp-app
  name: big-corp-app
spec:
  volumes:
  - name: logs
    emptyDir: 
  containers: 
  - image: registry.cn-zhangjiakou.aliyuncs.com/breezey/bar
    name: big-corp-app
    volumeMounts:
    - name: logs
      mountPath: /var/log
    resources: {}
  - name: busybox
    image: busybox
    volumeMounts:
    - name: logs
      mountPath: /var/log
    command:
    - "/bin/sh"
    - "-c"
    - "tail -n+1 /var/log/big-corp-app.log" 
  dnsPolicy: ClusterFirst
  restartPolicy: Always


kubectl apply -f big-corp-app.yaml

```



### 16. kubectl top pods

```
题目：
From the pod label name=cpu-loader, find pods running high CPU workloads and write the name of the pod consuming most CPU to file /opt/KUTR00401.txt(which alreay exists).
```

```bash
精简命令：

```

```bash
详细命令：
config env:
kubectl create deploy cpu-loader --image=mysql --replicas=5 --dry-run=client -o yaml > cpu-loader.yaml

---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    name: cpu-loader
  name: cpu-loader
spec:
  replicas: 5
  selector:
    matchLabels:
      name: cpu-loader
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        name: cpu-loader
    spec:
      containers:
      - image: mysql
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: wordpress
        resources: {}
status: {}


kubectl apply -f cpu-loader.yaml

answer:
s

# kubectl top pods -l name=cpu-loader -A --sort-by=cpu|grep -v NAME|head -1|awk '{print $1}' > /opt/KUTR00401.txt

```

```bash
参考答案：
# kubectl top pod -l name=cpu-user -A --sort-by cpu 
# kubectl top pods -l name=cpu-loader | sort -k2 -nr | head -1 | awk '{print $1}' > /tmp/cpu-loader.txt
```





### 17. docker -kubelet

```
题目：
A kubernetes worker node, named wk8s-node-0 is in state NotReady. Investigate why this is the case, and perform any appropriate steps to bring the node to a Ready state,ensuring that any changes are made permanent.

tips: 

you can ssh to the failed node using:
ssh wk8s-node-0

you can assume elevated privileges on the node with the following command：
sudo  -i 

```

```bash
精简命令：

```

```bash
详细命令：
# kubectl get nodes
# kubectl describe nodes cka-worker1
此处注意下节点的Container Runtime Version是containerd还是docker
Container Runtime Version:  containerd://1.6.20
Container Runtime Version:  docker://23.0.1

# ssh wk8s-node-0
# sudo -i

# systemctl status docker
或者# systemctl status containerd


# systemctl start docker 
或者# systemctl start containerd

# systemctl start kubelet 

# systemctl enable kubelet docker

```

