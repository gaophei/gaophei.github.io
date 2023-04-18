### 0. kubectl context设置---注意集群的不同

```bash
精简命令：
# kubectl config get-contextx
# kubectl config current-context

# kubectl config use-context xxx@yyyyy

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
```



### 2. kubectl drain设置

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：
# kubectl config use-context ek8s
# kubectl drain node ek8s-node-1 --ignore-daemonsets
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

# kubectl drain node ek8s-node-1 --ignore-daemonsets
```



### 3. xxx

```
题目：
Given an existing kubernetes cluster running version 1.26.3, upgrade all of the kubernetes control plain and node components on the master node only to version 1.26.4.
you are also expected to upgrade kubelet and kubectl on the master node 

tips: Be sure to drain the master node before upgrading it and uncordon it after the upgrade.
Do not upgrade the worker nodes,etcd,the container manager,the CNI plugin, the DNS service or any other addons.

```

```bash
精简命令：

```

```bash
详细命令：
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




### 4. xxx


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

```

```bash
详细命令：
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
root@k8s-master:~/cka# kubectl -n internal describe networkpolicies allow-port-from-namespace 
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




### 6. xxx

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

```




### 7. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```




### 8. xxx
```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```





### 9. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```




### 10. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```


### 11. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```




### 12. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```


### 13. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```



### 14. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```

### 15. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```



### 16. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```





### 17. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```



### 18. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```

### 19. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```



### 20. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```



### 21. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```



### 22. xxx

```
题目：
将一个名为ek8s-node-1的节点设置为不可用并将其上的pod重新调度
```

```bash
精简命令：

```

```bash
详细命令：

```
