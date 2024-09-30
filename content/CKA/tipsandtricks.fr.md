---
title: 'Trucs et astuces pour la CKA'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 30
tags: ["kubernetes", "CKA"]
---

# Avant l'examen

## Instructions importantes

- [Agree to Global Candidate Agreement](https://docs.linuxfoundation.org/tc-docs/certification/lf-cert-agreement)
- [Get Candidate Handbook](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2)
- [Read the Important Instructions](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks)

![CKS Homepage](https://k8s-school.fr/labs/images/LF-CKS-homepage.png?width=20vw)

## Vérification de la compatibilité de votre système

Toutes les informations sont sur [cette page du site](https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad) de la fondation Linux, à effectuer quelques jours avant l'examen.

## Simulateur:

Deux sessions de simulateur sont offertes, elles sont plus complexes que la CKA elle-même et constituent un excellent entraînement.
https://killer.sh/


## Accès à la documentation

Pour les examens CKA, il est permis d'utiliser certains sites web et documentations pour rechercher des terminologies et trouver des réponses à vos questions. Voici les sites autorisés :

- [Documentation officielle de Kubernetes](https://kubernetes.io/doc)
- [Blog officiel de Kubernetes](https://kubernetes.io/blog)
- [Github officiel de Kubernetes](https://github.com/kubernetes)

Développer une bonne connaissance de ces documents peut vous aider à gagner en agilité et en rapidité pendant l'examen. De plus, ces documents vous aideront à développer une solide base en Kubernetes. Utilisez uniquement ces sites pour rechercher des concepts et des outils, et préparez vos réponses. Apprenez également à utiliser efficacement les fonctions de recherche dans toute la documentation K8 et à mettre en favori toutes les pages pertinentes et utiles.

# Le jour de l'examen


Ces [trucs et astuces pour Linux]({{% ref "/0_Prereqs/tipsandtricks" %}} "About Us") peuvent être utiles.

## Les contexts

Il est recommandé d'utiliser `kubectx` en production mais cette outil n'est pas disponible durant la CKA. Voici donc les principales commandes de gestion des contextes à connaître:

```shell
# Liste les contextes
kubectl config get-contexts
# Change de contexte
kubectl config set-context <context-name>
# Modifie le contexte courant, ici pour travailler dans le namespace <my-namespace>
kubectl config set-context  --current --namespace <my-namespace>
```

## Pré-configuration
Une fois que vous avez accès à votre terminal, il peut être judicieux de passer environ 1 minute à configurer votre environnement. Vous pouvez définir ces éléments :

```shell
alias k=kubectl # sera déjà pré-configuré

export do="--dry-run=client -o yaml"
# k get pod x $do

export now="--force --grace-period 0"
# k delete pod x $now
```

## Vim

Pour que vim utilise 2 espaces pour une tabulation, éditez `~/.vimrc` pour ajouter :

```
set tabstop=2
set expandtab
set shiftwidth=2
```


