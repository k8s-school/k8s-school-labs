---
title: 'Installation de la plate-forme pédagogique'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 40
tags: ["kubernetes", "ktbx", "pre-requis"]
---

Durant la formation, il est recommandé d'utiliser la plate-forme mise à disposition. Cette section décrit comment reproduire cette dernière suite à la formation, pour rejouer les labs.

## Pré-requis

### Configuration de la machine locale

- Ubuntu LTS est recommandé
- 8 coeurs, 16 Go de RAM, 30Go pour la partition hébergeant les entités docker (images, volumes, conteneurs etc). Utiliser la commande `df` comme ci-dessous pour trouver sa taille.
```bash
sudo df -sh /var/lib/docker # ou /var/snap/docker/common/var-lib-docker/
```
- Accès internet **sans proxy**
- Accès `sudo`
- Installer les dépendances ci-dessous:
```shell
sudo apt-get install curl docker.io git vim

# puis ajouter l'utilisateur actuel au groupe docker
sudo usermod -a -G docker $USER
# ou redémarrer la session gnome
newgrp docker
```

Ensuite, vous pourrez créer le cluster Kubernetes en deux lignes en suivant la documentation de [ktbx]

<!--links-->
[ktbx]: https://github.com/k8s-school/ktbx

