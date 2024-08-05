all: check install

check:
	@./scripts/checks.sh

install:
	@./scripts/wireguard.sh
	@./scripts/ingress.sh