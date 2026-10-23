NS_ARGO ?= argocd-celc
NS_MON ?= monitoring-celc
GRAFANA_PASSWORD ?= admin-celc
IP ?= 192.168.49.240

.PHONY: all observability metallb traefik route argocd gitops hosts bridge verify clean

all: metallb traefik route argocd gitops observability hosts verify

observability:
	kubectl apply -f monitoring/namespace.yaml
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install prometheus prometheus-community/prometheus -n $(NS_MON) -f monitoring/prometheus/values.yaml --wait --timeout 5m
	kubectl apply -f monitoring/loki/loki.yaml
	kubectl apply -f monitoring/promtail/promtail.yaml
	kubectl -n $(NS_MON) create secret generic grafana-admin --from-literal=admin-user=admin --from-literal=admin-password=$(GRAFANA_PASSWORD) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(NS_MON) create configmap grafana-dashboards --from-file=monitoring/grafana/dashboards --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f monitoring/grafana/grafana.yaml
	kubectl apply -f monitoring/ingress.yaml
	kubectl -n $(NS_MON) rollout status deployment grafana --timeout=180s

metallb:
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
	kubectl -n metallb-system rollout status deployment controller --timeout=180s
	kubectl -n metallb-system rollout status daemonset speaker --timeout=180s
	sleep 10
	kubectl apply -f metallb/metallb-config.yaml

traefik:
	helm repo add traefik https://traefik.github.io/charts
	helm repo update
	helm upgrade --install traefik traefik/traefik -n traefik --create-namespace -f traefik/values.yaml --wait
	kubectl -n traefik get svc traefik

route:
	sudo ip route replace $(IP)/32 via $$(minikube ip)

argocd:
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	helm upgrade --install argocd argo/argo-cd -n argocd-celc --create-namespace -f argocd/values.yaml --wait
	kubectl apply -f argocd/ingress.yaml

gitops:
	kubectl apply -f argocd/applications/
	sleep 20
	kubectl -n $(NS_ARGO) get applications

hosts:
	./scripts/hosts.sh $(IP)

bridge:
	docker compose -f bridge/docker-compose.yaml up -d

verify:
	@for h in argocd app1 app2 app3 app4 grafana prometheus; do curl -sL -o /dev/null -w "$$h -> %{http_code}\n" http://$$h.parcial.local; done

clean:
	kubectl delete -f apps/apps.yaml --ignore-not-found
	helm uninstall traefik -n traefik || true
	kubectl delete namespace traefik --ignore-not-found
	kubectl delete -f metallb/metallb-config.yaml --ignore-not-found
	kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml --ignore-not-found
	docker compose -f bridge/docker-compose.yaml down || true