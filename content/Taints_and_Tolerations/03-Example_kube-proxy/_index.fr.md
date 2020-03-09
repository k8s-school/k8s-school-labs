+++
menuTitle = "Exemple: kube-proxy"
date = 2020-03-09T08:46:52Z
weight = 3
chapter = false
pre = "<b>- </b>"
tags = ["Kubernetes", "Scheduler", "Taints", "Tolerations", "kube-proxy", "Services"]
+++

# L'exemple de kube-proxy

**`kube-proxy` est un Daemonset Kubernetes dédié à la gestion du réseau virtuel des Services Kubernetes.** L'implémentation par défaut installe un pod `kube-proxy` sur chaque noeud en charge de gérer les adresses IP virtuelles des Services Kubernetes. 

{{% notice note %}}
Afin de créer le réseau virtuel des services `kube-proxy` configure le [module IPVS du noyau Linux](http://www.linuxvirtualserver.org/software/ipvs.html) sur chaque noeuds en parallèle. *Dans les versions plus anciennes de Kubernetes, `kube-proxy` configurait les `iptables` mais IPVS est bien plus rapide.*
{{% /notice %}}

Ce pod s'exécute également sur les noeud(s )maître(s) du cluster Kubernetes.
```bash
$ kubectl get pods -n kube-system --selector k8s-app=kube-proxy -o wide
NAME               READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
kube-proxy-pqcdm   1/1     Running   0          78m   172.17.0.3   kind-control-plane   <none>           <none>
kube-proxy-qbklt   1/1     Running   0          78m   172.17.0.2   kind-worker2         <none>           <none>
kube-proxy-sjl66   1/1     Running   0          78m   172.17.0.4   kind-worker          <none>           <none>
```

Listons les `Tolerations` dans la section `Pod template` du Daemonset `kube-proxy`:
```bash
kubectl get daemonsets.apps -n kube-system kube-proxy -o jsonpath="{.spec.template.spec.tolerations}"
[map[key:CriticalAddonsOnly operator:Exists] map[operator:Exists]]
```

Ou, la même chose en `yaml`
```yaml
# Extrait de stdout pour la commande: kubectl get daemonsets.apps  -n kube-system kube-proxy -o yaml
tolerations:
- key: CriticalAddonsOnly
  operator: Exists
- operator: Exists
```

Si l'on se réfère à [la documentation officielle](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/), nous sommes ici dans un cas particulier:

> An empty key with operator Exists matches all keys, values and effects which means this will tolerate everything.

Ainsi la `Toleration` ci-dessous permettra à un Pod de s"éxécuter sur tous les noeuds, peut importe leurs `Tolerations`. 
```yaml
tolerations:
- operator: "Exists"
```

C'est bien la raison pour laquelle le Daemonset **`kube-proxy` est en mesure d'éxécuter un pod sur le(s) noeud(s) maître(s)** du cluster Kubernetes.