NS_APPS ?= parcial-celc
IP ?= 192.168.49.240

.PHONY: all metallb traefik apps route hosts bridge verify clean

all: metallb traefik apps route hosts verify

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

apps:
	kubectl apply -f apps/apps.yaml
	kubectl -n $(NS_APPS) wait --for=condition=available deployment --all --timeout=180s
	kubectl -n $(NS_APPS) get deploy,svc,ingress

route:
	sudo ip route replace $(IP)/32 via $$(minikube ip)

hosts:
	./scripts/hosts.sh $(IP)

bridge:
	docker compose -f bridge/docker-compose.yaml up -d

verify:
	@for n in 1 2 3 4; do curl -s -o /dev/null -w "app$$n -> %{http_code}\n" http://app$$n.parcial.local; done

clean:
	kubectl delete -f apps/apps.yaml --ignore-not-found
	helm uninstall traefik -n traefik || true
	kubectl delete namespace traefik --ignore-not-found
	kubectl delete -f metallb/metallb-config.yaml --ignore-not-found
	kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml --ignore-not-found
	docker compose -f bridge/docker-compose.yaml down || true