---

title: 'Docker : l'essentiel'
date: 2024-07-07T14:15:26+10:00
draft: false
weight: 0
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

1. Remplacez `<ID>` par un numéro unique de votre choix (par exemple, 1) et exécutez la commande suivante pour lancer un conteneur Ubuntu avec Netcat :


{{%expand "Solution" %}}
```bash
docker run --name "netcat<ID>" -d -p 808<ID>:80 -- \
ubuntu sh -c "apt-get update && apt-get -y install netcat && echo 'Run netcat' && netcat -l -p 80"
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

## Démarrer un conteneur nommé “mariadbtest” et exécuter une instance mariadb

{{%expand "Solution" %}}
```bash
# Démarrer un conteneur nommé “mariadbtest” et exécuter une instance mariadb

# mariadbtest est le nom que nous voulons attribuer au conteneur. Si nous ne spécifions pas de nom, un identifiant sera généré automatiquement.
docker run --name mariadbtest -e MYSQL_ROOT_PASSWORD=mypass -d mariadb

# Facultativement, après le nom de l'image, nous pouvons spécifier des options pour mysqld. Par exemple :
docker run --name mariadbtest -e MYSQL_ROOT_PASSWORD=mypass -d mariadb --log-bin --binlog-format=MIXED

# lister les conteneurs en cours d'exécution
docker ps
```
{{% /expand%}}

### Exercice

1. Démarrez un conteneur nommé `mariadbtest` avec le mot de passe root pour MySQL défini sur `mypass` :

{{%expand "Solution" %}}
```bash
docker run --name mariadbtest -e MYSQL_ROOT_PASSWORD=mypass -d mariadb
```
{{% /expand%}}

2. Vérifiez que le conteneur est en cours d'exécution :

{{%expand "Solution" %}}
```bash
docker ps
```
{{% /expand%}}

3. Optionnellement, vous pouvez ajouter des options pour `mysqld` comme indiqué dans l'exemple ci-dessus.

## Installer vim dans le conteneur mariadbtest

{{%expand "Solution" %}}
```bash
# Accéder au conteneur via bash, avec accès root
docker exec -it mariadbtest bash

# Installer des logiciels à l'intérieur du conteneur
apt-get update && apt-get install vim
```
{{% /expand%}}

### Exercice

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

## Créer un Dockerfile pour exécuter un serveur web python

Allez dans le répertoire de l'exercice :

```bash
cd k8s-school/labs/0_docker/webserver
```

### Exercice

Trouvez la commande pour construire le conteneur et le taguer avec le label `webserver<ID>`.

1. Construisez le conteneur et taguez-le avec le label `webserver<ID>` (remplacez `<ID>` par un numéro unique) :

{{%expand "Solution" %}}
```bash
docker build --tag=webserver<ID> .
```
{{% /expand%}}

Utilisez l'exemple de `Dockerfile` dans le répertoire actuel et mettez-le à jour.

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

### Exercice

1. Créez un `Dockerfile` basé sur l'exemple ci-dessus.
2. Construisez l'image Docker et taguez-la :

{{%expand "Solution" %}}
```bash
docker build --tag=webserver<ID> .
```
{{% /expand%}}

## Lancer le conteneur en tant que daemon et publier le port 8000 sur l'hôte

Vérifiez le fichier python à l'intérieur du conteneur pour trouver le port à exporter.

### Exercice

1. Lancer le conteneur en tant que daemon et publier le port 8000 sur l'hôte :

{{%expand "Solution" %}}
```bash
docker run -d --name mywww -t -p 8000:8000 webserver<ID>
```

2. Vérifiez que le conteneur est en cours d'exécution et accédez au site web

{{%expand "Solution" %}}
   ```bash
   docker ps
   curl http://localhost:8080
   ```
{{% /expand%}}

3. Supprimez le conteneur :

{{%expand "Solution" %}}
   ```bash
   docker rm -f mywww
   ```
{{% /expand%}}

## Lancer le conteneur en tant que daemon et publier le port 8000 sur l'hôte, et utiliser le fichier html stocké sur la machine hôte

### Exercice

1. Lancez le conteneur en tant que daemon, publiez le port 8000 sur l'hôte, et utilisez le fichier html stocké sur la machine hôte :

{{%expand "Solution" %}}
   ```bash
   docker run --name my_webserver -d -p 8000:8000 -v $PWD/www:/home/www webserver<ID>
   ```
{{% /expand%}}

2. Vérifiez que le conteneur est en cours d'exécution et que le fichier HTML est servi correctement.

{{%expand "Solution" %}}
   ```bash
   docker ps
   curl http://localhost:8080
   ```
{{% /expand%}}
