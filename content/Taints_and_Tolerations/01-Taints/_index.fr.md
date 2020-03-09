+++
menutitle = "Taints"
date = 2020-03-09T08:46:52Z
weight = 1
chapter = false
pre = "<b>- </b>"
tags = ["Kubernetes", "Scheduler", "Taints"]
+++

# Ajouter des Taints aux noeuds Kubernetes

Pour faire simple, **ajouter une `Taint` à un nœud revient à appliquer une mauvaise odeur sur ce nœud. Seuls les Pods qui tolèrent cette mauvaise odeur pourront être exécutés sur le nœud.**

Tout comme les Labels, une ou plusieurs Taints peuvent être appliquées à un nœud; cela signifie que le nœud ne doit accepter aucun pod qui ne tolère pas l'ensemble de ces Taints.

Les Taints sont de la forme: `key=value:Effect`.

### Signification du champ "Effects"

Le champ "Effects" peut prendre les trois valeurs ci-dessous:

- `NoSchedule` - L'exécution des pods non tolérants à la Taint ne sera pas planifiée sur ce nœud. Il s'agit d'une **contrainte forte**  pour le Scheduler Kubernetes.

- `PreferNoSchedule`-  Le Scheduler Kubernetes évitera de placer un `Pod` qui ne tolère pas la Taint sur le nœud, mais ce n'est pas obligatoire. Il s'agit d'une **contrainte douce** pour le Scheduler Kubernetes.

- `NoExecute` - Le pod sera expulsé du nœud *(s'il est déjà en cours d'exécution sur le nœud)* ou ne sera pas planifié sur le nœud *(s'il n'est pas encore exécuté sur le nœud)*. Il s'agit d'une **contrainte forte**  pour le Scheduler Kubernetes.

### Gestion des Taints

Listons les Taints sur le noeud maître d'un cluster Kubernetes multi-noeuds basé sur [kind](https://kind.sigs.k8s.io/) et créé avec l'[outil de k8s-school](https://github.com/k8s-school/kind-travis-ci):

```shell
$ kubectl get nodes kind-control-plane -o jsonpath="{.spec.taints}"
[map[effect:NoSchedule key:node-role.kubernetes.io/master]]
```

La Taint nommée `node-role.kubernetes.io/master="":NoSchedule` a été aposée par [kind](https://kind.sigs.k8s.io/) *(en réalité par kubeadm, sur lequel s'appuie kind)* sur le noeud maître du cluster. Elle permettra au Scheduler de ne pas planifier des Pods classiques sur le noeud maître du cluster et de réserver celui-ci aux Pods systèmes tels que le `Serveur d'API`, le `Scheduler`, le `Controller` ou encore le `kube-proxy` et le plugin `CNI`.

Il est possible de supprimer cette Taint très simplement, afin de permettre l'exécution de Pods applicatifs sur le noeud maître. Cette opération est déconseillé pour la production mais peut-être utile dans le cadre d'un cluster Kubernetes de développement par exemple.
```shell
$ kubectl taint node kind-control-plane node-role.kubernetes.io/master-
node/kind-control-plane untainted
```

Pour remettre la Taint en place:
```shell
$ kubectl taint node kind-control-plane node-role.kubernetes.io/master="":NoSchedule
```

{{% notice note %}}
A noter que la Taint n'a pas pour effet `NoExecute` mais bien `NoSchedule`, donc les Pods applicatifs exécutés sur le noeuds dans l'intervalle de temps durant lequelle elle n'était plus présente ne seront pas expulsés automatiquement par Kubernetes.

