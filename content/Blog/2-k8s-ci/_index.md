---
title: 'Easily run a multinode Kubernetes cluster on your CI'
date: 2019-10-14T15:15:26+10:00
image: '/services/default.png'
featured: true
draft: false
---

**Written by:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)). 
**Date:** Oct 14, 2019 · 10 min read

This tutorial tutorial shows how to **automate the tests of a Cloud-Native application**. It will allow you to run and test your Kubernetes applications inside a CI server.

## Pre-requisites

* Your Kubernetes application will be stored inside a [Github](https://github.com) project
* The continuous integration server will rely on [Travis-CI](https://travis-ci.org), which may be used freely
* Connect the Github project to Travis-CI, by going to url https://travis-ci.org/<USER>/<PROJECT_NAME> and activating the project inside Travis-CI web interface. Once this is done, Travis-CI will launch a new virtual machine for each new Github commit.

## Kind: what is it?

[kind](https://kind.sigs.k8s.io/) is a tool for running local Kubernetes clusters using Docker container “nodes”.
 

![Kind architecture](ci_kind.png?class=shadow?width=80pc)

- kind: see [this repos](https://github.com/k8s-school/kind-travis-ci.git)

Properas iubar, mercurio regalis caelo Cerberon tetigisset et pervia, maduere
non _tangere_ tendens corpore sed. Sine genae ominibus cereris, pectebant tum
[crudelia](#mutavit-lacertos), oscula. Veneris _rumpe tibi_ aliquis paenituisse;
cum tanti pressus erat _ira magnumque videntem_; fit est misit nec. Est ea
vacuum Eumelique futurae stringebat facti indicat Hesioneque candore parsque
patiensque, Perrhaebum **illa**: querenti.

1. Deum sibi poma lacuque fateor
2. Nisi vultibus adspicio totosque gladios a novatrix
3. Regna ducebat

_Fuit_ eurus promissaque. Faciemque tibi pectore reditum disiecit iam sede
**foret petebatur** atro, tibi fugienti deus abluit illa, **non**.

## Install the application 

- redis operator or mongodb?
- launch the test
- push the new version of the container to the container registry

