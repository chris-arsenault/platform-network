.PHONY: ci fmt fmt-check deploy

ci: fmt-check

fmt:
	terraform fmt -recursive infrastructure/terraform/

fmt-check:
	terraform fmt -check -recursive infrastructure/terraform/

deploy:
	scripts/deploy.sh
