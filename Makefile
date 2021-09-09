.PHONY: static-tests unit-tests integration-tests e2e-tests init

# OS can be "Linux" or "macOS"
OS ?= Linux
# ARCH can be "x86_64" or "arm64"
ARCH ?= x86_64

TERRAFORM_VERSION := 1.0.6
REGULA_VERSION := 1.3.0
TFLINT_VERSION := 0.31.0
CONFTEST_VERSION := 0.27.0
TF_COMPLIANCE_VERSION := 1.3.26

SHELL := /usr/bin/env bash

static-tests: setup-env
    # should not require any aws credentials to test against, should be safe to run as github checks on pull requests
	terraform validate
	terraform fmt -check -recursive ./ || ( echo 'FAILED: all tf files should be formatted using "terraform fmt"'; exit 1 )
	tflint --module --loglevel=info --var='region=us-west-1' --var='create_vpc=true' ./
	regula run
	# terraform-compliance and conftest need a plan file to work off
	terraform plan -out=plan.out -var 'create_vpc=true' -var 'region=us-west-2' -var "enable_dns_hostnames=true" -var "name=testplan"
	# conftest ## custom rules must be written https://github.com/open-policy-agent/conftest/tree/master/examples/hcl2
	# TODO: looks like we need to provide custom features(read tests) to make terraform-compliance useful
	terraform-compliance -S -f git:https://github.com/terraform-compliance/user-friendly-features.git -p plan.out

unit-tests: setup-env
	# Should test code paths in an individual module. terratest, or `terraform test`, this is where you want to test different regions, use retries to smooth transient errors
	# Should not run automatically on PR's from un-trusted contributors
	cd test && go test -timeout 30m -json | go-test-report

integration-tests:
    # Should test code paths in a module of modules and run when on eof the sub-modules is updated. terratest, or `terraform test` use retries to smooth transient errors
	# Should not run automatically on PR's from un-trusted contributors, and should only be run on modules where one sub-module is changed
	echo "todo"
	exit 1

e2e-tests:
    # Should test code paths in `deploy/` module. Unsure whether it should use tf cloud. terratest, or `terraform test`.
    # For deploys that take long you could skip destroy between runs, so e2e is just updating what changed from last iteration, use retries to smooth transient errors.
	# Should not run automatically on PR's from any contributors. Update(no destroy) tests run on `/do-e2e-tests` PR comment from maintainers. Full e2e run on release.
	echo "todo"
	exit 1

setup-env:
	mkdir -p build/bin/ &&\
		export PATH=$(shell pwd)/build/bin:$${PATH} &&\
		export TF_ARCH=$(shell echo $(ARCH) | sed 's/x86_64/amd64/') &&\
		export TF_OS=$(shell echo $(OS) | tr '[:upper:]' '[:lower:]' | sed 's/macos/darwin/') &&\
		export CT_OS=$(shell echo $(OS) | sed 's/macOS/Darwin/') &&\
		if [ "$$(terraform -v  | head -n 1 | sed 's/Terraform v//')" != "$(TERRAFORM_VERSION)" ]; then \
			wget -O tf.zip https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$${TF_OS}_$${TF_ARCH}.zip &&\
			unzip -o tf.zip &&\
			rm tf.zip &&\
			mv -fv terraform build/bin/ ;\
		fi ;\
		if [ "$$(tflint --version  | head -n 1 | sed 's/TFLint version //')" != "$(TFLINT_VERSION)" ]; then \
			wget -O tflint.zip https://github.com/terraform-linters/tflint/releases/download/v$(TFLINT_VERSION)/tflint_$${TF_OS}_$${TF_ARCH}.zip &&\
			unzip -o tflint.zip &&\
			rm tflint.zip &&\
			mv -fv tflint build/bin/ ;\
		fi &&\
		if [ "$$(regula version | awk -F',' '{print $$1}' | sed 's/v//')" != "$(REGULA_VERSION)" ]; then \
			wget -O regula.tgz https://github.com/fugue/regula/releases/download/v$(REGULA_VERSION)/regula_$(REGULA_VERSION)_$(OS)_$(ARCH).tar.gz &&\
			tar -xvf regula.tgz &&\
			rm regula.tgz &&\
			mv -fv regula build/bin/ ;\
		fi &&\
		if [ "$$(conftest --version  | sed 's/Version: //')" != "$(CONFTEST_VERSION)" ]; then \
			wget -O conftest.tgz https://github.com/open-policy-agent/conftest/releases/download/v$(CONFTEST_VERSION)/conftest_$(CONFTEST_VERSION)_$${CT_OS}_$(ARCH).tar.gz &&\
			tar -xvf conftest.tgz &&\
			rm conftest.tgz &&\
			mv -fv conftest build/bin/ ;\
		fi &&\
		if [ "$$(terraform-compliance -v  | tail -n 1)" != "$(TF_COMPLIANCE_VERSION)" ]; then \
		    pip install --upgrade "terraform-compliance==$(TF_COMPLIANCE_VERSION)" ;\
		fi
