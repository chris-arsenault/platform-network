.PHONY: fmt deploy

fmt:
	terraform fmt -recursive infrastructure/terraform/

deploy:
	scripts/deploy.sh
