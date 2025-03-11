---
title: "Docker : l'essentiel"
date: 2024-07-07T14:15:26+10:00
draft: false
weight: 5
tags: ["docker", "container", "devops"]
---

## Monter un volume de données persistant (option --volume)

### Exemple

```bash
# Persister les données du conteneur sur l'hôte
docker run -it -v /host-data:/data ubuntu
```

### Exercice

Créer un conteneur ubuntu qui monte le répertoire `/etc` de l'hôte dans `/hack/etc`.

1. Exécutez la commande suivante pour lancer un conteneur Ubuntu en montant le répertoire `/etc` de l'hôte :

   ```bash
   docker run -it -v /etc:/hack/etc ubuntu
   ```

2. Vérifiez l'accès aux fichiers `/etc` de l'hôte depuis l'intérieur du conteneur en listant les fichiers du répertoire `/hack/etc` :

   ```bash
   ls /hack/etc
   ```

3. Vous devriez voir les fichiers et répertoires présents dans `/etc` de l'hôte.

## Publier un port réseau (option --publish)

### Exemple

```bash
# Mapper le port 80 du conteneur au port 8080 de l'hôte
docker run -it -p 8080:80 ubuntu netcat -l -p 80
```

### Exercice

Créer un conteneur ubuntu qui exécute `netcat -l -p 80` et expose le port `808<ID>` sur l'hôte.

1. Remplacez `<ID>` par un numéro unique (par exemple 1 si vous êtes `k8s1`) et lancer un conteneur Ubuntu avec Netcat :


   {{%expand "Solution" %}}
   ```bash
   docker run --name "netcat<ID>" -d -p 808<ID>:80 -- \
   ubuntu sh -c "apt-get update && apt-get -y install netcat-traditional && echo 'Run netcat' && netcat -l -p 80"
   ```
   {{% /expand%}}

2. Vérifiez que le conteneur est en cours d'exécution :

   {{%expand "Solution" %}}
   ```bash
   docker ps
   ```
   {{% /expand%}}

3. Testez la connexion depuis l'hôte en utilisant Netcat :

   {{%expand "Solution" %}}
   ```bash
   netcat localhost 808<ID>
   ```
   {{% /expand%}}

4. Si la connexion est établie, tapez quelque chose dans le terminal et vous devriez voir la même chose dans le conteneur (vous pouvez vérifier les logs avec `docker logs netcat`).

{{% notice note %}}
Utilisez `CtrlẐ` puis `bg` pour mettre la commande `netcat` précédente en tâche de fond.
{{% /notice %}}


## Cas pratique

### Partie 1: Exécuter un conteneur

1. Démarrez un conteneur nommé `mariadbtest` avec le mot de passe root pour MySQL défini sur `mypass` :

   {{%expand "Solution" %}}
   ```bash
   docker run --name mariadbtest<ID> -e MYSQL_ROOT_PASSWORD=mypass -d mariadb
   ```
   {{% /expand%}}

2. Vérifiez que le conteneur est en cours d'exécution :

   {{%expand "Solution" %}}
   ```bash
   docker ps
   ```
   {{% /expand%}}

3. Optionnellement, vous pouvez ajouter des options pour `mysqld` comme indiqué dans l'exemple ci-dessous.

   {{%expand "Solution" %}}
   ```bash
   docker run --name mariadbtest<ID> -e MYSQL_ROOT_PASSWORD=mypass -d mariadb --log-bin --binlog-format=MIXED
   ```
   {{% /expand%}}

### Partie 2: Accéder interactivement à un conteneur

1. Accédez au conteneur `mariadbtest` via bash :

   {{%expand "Solution" %}}
   ```bash
   docker exec -it mariadbtest bash
   ```
   {{% /expand%}}

2. Mettez à jour les paquets et installez vim :

   {{%expand "Solution" %}}
   ```bash
   apt-get update && apt-get install vim
   ```
   {{% /expand%}}

3. Vérifiez que vim est installé en tapant `vim` dans le terminal du conteneur.

### Partie 3: Créer une image de conteneur pour exécuter un serveur web python

#### Création de l'image

Allez dans le répertoire de l'exercice :

```bash
git clone https://github.com/k8s-school/k8s-school
cd k8s-school/labs/0_docker/webserver
```

Trouvez la commande pour construire le conteneur et le taguer avec le label `webserver<ID>`.

1. Construisez le conteneur et taguez-le avec le label `webserver<ID>` (remplacez `<ID>` par un numéro unique) :

   {{%expand "Solution" %}}
   ```bash
   docker build --tag=webserver<ID> .
   ```
   {{% /expand%}}

2. Utilisez l'exemple de `Dockerfile` dans le répertoire actuel et mettez-le à jour petit à petit en démarrant par le haut du fichier.

   {{%expand "Solution" %}}
   ```bash
   # Utiliser ubuntu comme image de base, elle sera téléchargée automatiquement
   FROM ubuntu:latest
   LABEL org.opencontainers.image.authors "fabrice.jammes@gmail.com"

   # Mettre à jour et installer les dépendances système
   RUN apt-get update && apt-get install -y python3
   RUN mkdir -p /home/www
   WORKDIR /home/www
   # Les commandes ci-dessous seront toutes exécutées dans WORKDIR

   # Lancer la commande ci-dessous au démarrage du conteneur
   # Elle servira les fichiers situés là où elle a été lancée
   # donc /home/www
   CMD python3 /home/src/hello.py

   # Ajouter un fichier local à l'intérieur du conteneur
   # le code peut également être récupéré à partir d'un dépôt git
   COPY index.html /home/www/index.html

   # Cette commande est la dernière, donc si hello.py est modifié
   # seule cette couche du conteneur sera modifiée.
   COPY hello.py /home/src/hello.py
   ```
   {{% /expand%}}

#### Exécution du conteneur

Analyser le programme python `hello.py` à l'intérieur du conteneur pour trouver le port à exporter.

1. Lancer le conteneur en tant que daemon et publier le port 800<ID> sur l'hôte :

   {{%expand "Solution" %}}
   ```bash
   docker run -d --name k8s<ID>_www -t -p 800<ID>:8000 webserver<ID>
   ```
   {{% /expand%}}

2. Vérifiez que le conteneur est en cours d'exécution et accédez au site web

   {{%expand "Solution" %}}
   ```bash
   docker ps
   curl http://localhost:800<ID>
   ```
   {{% /expand%}}

3. Supprimez le conteneur :

   {{%expand "Solution" %}}
   ```bash
   docker rm -f k8s<ID>_www
   ```
   {{% /expand%}}

4. Lancez le conteneur en tant que daemon, publiez le port 800<ID> sur l'hôte, et utilisez le fichier html stocké sur la machine hôte :

   {{%expand "Solution" %}}
   ```bash
   docker run --name k8s<ID>_www_data -d -p 800<ID>:8000 -v $HOME/k8s-school/labs/0_docker/www:/home/www webserver<ID>
   ```
   {{% /expand%}}

5. Vérifiez que le conteneur est en cours d'exécution et que le fichier HTML est servi correctement.

   {{%expand "Solution" %}}
   ```bash
   # Editer le fichier $PWD/www/index.html
   docker ps
   curl http://localhost:800<ID>
   ```
   {{% /expand%}}
