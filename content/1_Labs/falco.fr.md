---
title: 'Runtime Security (Falco)'
date: 2024-06-06T16:00:00+10:00
draft: false
weight: 40
tags: ["CKS", "Falco", "Runtime"]
---

## Objectifs
Utiliser Falco pour détecter des comportements suspects à l'intérieur des conteneurs en temps réel.

## Prerequisites
```bash
# Vérifier que le service Falco est actif
systemctl status falco

```

## Détecter une intrusion

Utilisez `kubectl exec` pour entrer dans un pod et tentez de lire un fichier sensible.

{{%expand "Solution" %}}

```bash
# Dans un terminal
kubectl exec -it <pod_name> -- sh
cat /etc/shadow

# Dans un autre terminal, observez les logs Falco
tail -f /var/log/syslog | grep "Notice"

```

{{% /expand%}}

## Créer une règle personnalisée

Modifiez `/etc/falco/falco_rules.local.yaml` pour créer une alerte spécifique.

{{%expand "Solution" %}}

```yaml
- rule: Shell au sein d'un conteneur
  desc: Détecter toute ouverture de shell
  condition: container.id != host and proc.name = sh
  output: "Shell ouvert dans le conteneur (user=%user.name container=%container.id)"
  priority: WARNING

```

{{% /expand%}}

```
