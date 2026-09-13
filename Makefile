.PHONY: build vet fmt test docs docs-check mirror validate clean

# Matches the version pinned in test/e2e/main.tf.
PROVIDER_VERSION ?= 0.0.0-ci
MIRROR_DIR := $(CURDIR)/.provider-mirror
MIRROR_PATH := $(MIRROR_DIR)/registry.terraform.io/henrikhalt/dryad/$(PROVIDER_VERSION)/$(shell go env GOOS)_$(shell go env GOARCH)
TFRC := $(CURDIR)/.terraformrc.local

build:
	go build ./...

vet:
	go vet ./...

fmt:
	gofmt -w main.go internal
	terraform fmt -recursive test examples

test:
	go test ./...

# Builds the provider into a local filesystem mirror and writes a CLI config
# pointing at it, so terraform can run against the working tree.
mirror:
	mkdir -p "$(MIRROR_PATH)"
	go build -o "$(MIRROR_PATH)/terraform-provider-dryad_v$(PROVIDER_VERSION)" .
	printf 'provider_installation {\n  filesystem_mirror {\n    path    = "%s"\n    include = ["registry.terraform.io/henrikhalt/dryad"]\n  }\n  direct {\n    exclude = ["registry.terraform.io/henrikhalt/dryad"]\n  }\n}\n' "$(MIRROR_DIR)" > "$(TFRC)"

validate: mirror
	rm -f test/e2e/.terraform.lock.hcl
	cd test/e2e && TF_CLI_CONFIG_FILE=$(TFRC) terraform init -upgrade -no-color >/dev/null
	cd test/e2e && TF_CLI_CONFIG_FILE=$(TFRC) terraform validate -no-color
	terraform fmt -check -recursive test examples

# Regenerates docs/ from the provider schema, examples/ and templates/.
docs:
	go run github.com/hashicorp/terraform-plugin-docs/cmd/tfplugindocs@latest generate \
		--provider-name dryad \
		--rendered-provider-name dryad

# Fails when docs/ is out of date with the schema.
docs-check: docs
	git diff --exit-code -- docs/

clean:
	rm -rf "$(MIRROR_DIR)" "$(TFRC)" test/e2e/.terraform test/e2e/.terraform.lock.hcl
