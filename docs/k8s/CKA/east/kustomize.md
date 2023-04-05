从kubernetes 1.14版本开始，kustomize被正式集成到kubectl命令当中，从此大家可以通过`kubectl apply -k`命令将kustomize语法的描述文件直接部署至kubernetes集群当中。

- kustomize 通过 Base & Overlays 维护不同环境的应用配置
- kustomize 使用 patch 方式复用 Base 配置，并在 Overlay 描述与 Base 应用配置的差异部分来实现资源复用
- kustomize 管理的都是 Kubernetes 原生 YAML 文件，学习成本低

Kustomize官方文档： [https://kubectl.docs.kubernetes.io/zh/guides/](https://kubectl.docs.kubernetes.io/zh/guides/)

Kustomize代码托管地址： [https://github.com/kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize)