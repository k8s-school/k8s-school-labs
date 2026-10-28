- Test labs
- Test platform install
- Openshift!!!
- After the OpenShift training: test the lab pages themselves in CI. Label the bash blocks to run (mdrip, kubernetes-sigs/mdrip, `<!-- @test -->`), hide waits/assertions in HTML comments, extract and run on kind with `set -euo pipefail`. Try first on rollout.en.md (no script today), check mdrip vs Relearn `{{% expand %}}`.
- Gateway API lab: add a note on the shared Gateway pattern (one Gateway owned by the trainer in a common namespace, `allowedRoutes.namespaces.from: All`, trainees only write HTTPRoutes with `parentRefs` to it and their own hostname `hello-$USER.info`). Matches the Gateway API role split (cluster operator vs app developer).
- Next OpenShift training (needs an OpenShift 4.19+ cluster, could not be done without it): drop the Routes lab (openshift-ingress-route.en.md, "Ingress, Routes" section of openshift-administration) and replace it with a Gateway API lab on OpenShift itself. Use the native Gateway API support of the Ingress Operator (GatewayClass with `controllerName: openshift.io/gateway-controller/v1`, Istio based, Gateway in `openshift-ingress`), instead of Envoy Gateway on kind. Reuse gateway-api-ab-testing.en.md (expose, canary, A/B testing) and test it step by step on the cluster.

QUALITE DE SERVICE
Utilisation optimale des ressources matérielles grâce aux Requests et Limits
Classes de QoS: Guaranteed, Burstable et BestEffort
Contrôle d’allocation des ressources par Namespace avec les ResourceQuota
Contrôle d’allocation des ressources par Pod avec les LimitRange
HELM
Architecture et fonctionnement
Cas pratique avec PostrgreSQL
INGRESS
Fonctionnement et cas pratique avec nginx-controller
GESTION DES LOGS AVEC EFK (ElasticSearch, Fluentd, Kibana)
DEVELOPPER AVEC KUBERNETES
Utilisation de téléprésence
Personnalisation d’un pod orienté débuggage (désactivation des sondes, modification de la commande de
démarrage)
Présentation de « kubectl debug »
ARCHITECTURE DE KUBERNETES (en fonction du temps restant dans la journée)
Les composants du Control Plane et des noeuds de travail
Philosophie Unix des composants

Fonctionnement de la boucle de réconciliation et du Controller Kubernetes
Fonctionnement de etcd en mode haute-disponibilité
Fonctionnement interne de l’API server: authentification, autorisation et
Admission Control
Gestion des contrôleurs d'admission
Description de l’algorithme du Scheduler Kubernetes, prédicats et priorités
