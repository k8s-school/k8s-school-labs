---
title: 'Installer Postgresql simplement avec Helm'
date: 2024-05-30T14:15:26+10:00
draft: false
weight: 30
tags: ["kubernetes", "helm", "postgresql", "installation"]
---

* En premier lieu, créer un `namespace` nommé `pgsql`

{{%expand "Solution" %}}
```bash
kubectl create namespace pgsql
```
{{% /expand%}}

* Ensuite consulter la [documentation](https://artifacthub.io/packages/helm/bitnami/postgresql) et le [code source](https://github.com/bitnami/charts/blob/main/bitnami/postgresql/README.md) du `helm chart postgresql`

* Trouver la ligne de commande `helm` unique qui permet d'installer `postgresql` avec le paramétrage suivant:
  - dans le `namespace` nommé `pgsql`
  - spécification de la version du `char` à utiliser
  - désactivation de la persistence de données
  - ajout d'un label `tier=database` sur le `pod postresql`
* Trouver la ligne de commande `helm` qui liste votre instance


{{%expand "Solution" %}}
```bash
helm install --version 15.0.0 --namespace helm pgsql oci://registry-1.docker.io/bitnamicharts/postgresql --set primary.podLabels.tier="database",persistence.enabled="false"
```
{{% /expand%}}

* Etudier la sortie standard du cette commande et l'utiliser pour se connecter à l'instance `postgresql`

{{%expand "Solution" %}}
```bash
# Interactive mode
export POSTGRES_PASSWORD=$(kubectl get secret --namespace helm pgsql-postgresql -o jsonpath="{.data.postgres-password}" | \
    base64 -d)
kubectl run pgsql-postgresql-client --rm --tty -i --restart='Never' --namespace helm \
    --image docker.io/bitnami/postgresql:14.5.0-debian-11-r14 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
    --command -- psql --host pgsql-postgresql -U postgres -d postgres -p 5432 -c '\copyright'
```
{{% /expand%}}

* Désinstaller cette instance de `postgresql`

{{%expand "Solution" %}}
```bash
helm delete pgsql -n helm
```
{{% /expand%}}

* Valider en étudiant le code de la [démo helm](https://github.com/k8s-school/demo-helm.git)
