---
title: 'Pod et hostpath'
date: 2025-03-11T14:15:26+10:00
draft: false
weight: 7
tags: ["Pod", "hostpath"]
---

# Exercice : Créer un Pod utilisant hostPath

Cet exercice vous guide à travers la création d'un Pod Kubernetes qui utilise un volume `hostPath` pour monter un répertoire du nœud hôte dans le conteneur. Nous allons ensuite créer un fichier dans ce volume et vérifier son existence à l'intérieur du conteneur.

## Prérequis

* Un cluster Kubernetes fonctionnel (par exemple, un cluster `kind`).
* `kubectl` configuré pour interagir avec votre cluster.

## Étapes

1.  **Créer le Pod avec un volume hostPath :**

Créez un fichier YAML nommé `5-5-kuard-pod-vol.yaml` avec le contenu suivant :

```yaml
apiVersion: v1
kind: Pod
metadata:
name: kuard-pod-hostpath
spec:
volumes:
- name: hostpath-vol
   hostPath:
      path: /var/lib/kuard
containers:
- image: gcr.io/kuar-demo/kuard-amd64:1
   name: kuard
   volumeMounts:
   - mountPath: /data
      name: hostpath-vol
```

Ce fichier définit un Pod nommé `kuard-pod-hostpath` qui utilise un volume `hostPath`. Le répertoire `/var/lib/kuard` du nœud hôte est monté dans le conteneur à `/data`.

Appliquez le fichier YAML pour créer le Pod.

{{%expand "Réponse" %}}
```bash
kubectl apply -f 5-5-kuard-pod-vol.yaml
```
{{% /expand%}}


2.  **Identifier le noeud sur lequel le pod est déployé:**

{{%expand "Réponses" %}}
```bash
kubectl get pod kuard-pod-hostpath -o wide
```

Notez le nom du nœud affiché dans la colonne `NODE`. Par exemple, `kind-worker3`.
{{% /expand%}}



3.  **Accéder au nœud hôte et créer un fichier :**

Utilisez `docker exec` pour accéder au nœud hôte (remplacez `kind-worker3` par le nom de votre nœud).

{{%expand "Réponse" %}}
```bash
docker exec -it kind-worker3 bash
```
{{% /expand%}}

Créez un fichier nommé `my-file` dans le répertoire `/var/lib/kuard`.

{{%expand "Réponse" %}}
```bash
echo "Hello from hostPath" > /var/lib/kuard/my-file
```
{{% /expand%}}

Quittez le shell du nœud hôte.

{{%expand "Réponse" %}}
```bash
exit
```
{{% /expand%}}

4.  **Vérifier l'existence du fichier dans le Pod :**

    Accédez au shell du conteneur dans le Pod.

{{%expand "Réponse" %}}
```bash
kubectl exec -it kuard-pod-hostpath -- bash
```
{{% /expand%}}

Vérifiez l'existence du fichier dans le répertoire monté `/data` :

{{%expand "Réponse" %}}
```bash
cat /data/my-file
```
{{% /expand%}}

Vous devriez voir le contenu du fichier : `Hello from hostPath`.

Vérifiez également l'existence du fichier dans le répertoire source du noeud `/var/lib/kuard`.

{{%expand "Réponse" %}}
```bash
cat /var/lib/kuard/my-file
```
{{% /expand%}}

Vous devriez voir le même contenu.

Quittez le shell du conteneur :

{{%expand "Réponse" %}}
```bash
exit
```
{{% /expand%}}

## Solutions

* Le fichier `my-file` créé sur le nœud hôte est visible dans le Pod car le répertoire `/var/lib/kuard` est monté dans le conteneur à `/data` en utilisant `hostPath`.
* Toute modification apportée au fichier sur le nœud hôte est immédiatement reflétée dans le conteneur, et vice versa.
* L'utilisation de `hostPath` permet aux conteneurs d'accéder directement au système de fichiers du nœud hôte, ce qui peut être utile pour certaines applications, mais doit être utilisé avec prudence en raison des risques de sécurité.
* `/var/lib/kuard` appartient à `root` car il n'existait pas préalablement à la création du pod. Le container runtime a donc du le créer et a utilisé les droits `root` par défaut.

