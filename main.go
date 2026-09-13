package main

import (
	"context"
	"log"

	"github.com/hashicorp/terraform-plugin-framework/providerserver"

	"github.com/henrikhalt/terraform-provider-dryad/internal/provider"
)

var version = "dev"

func main() {
	err := providerserver.Serve(context.Background(), provider.New(version), providerserver.ServeOpts{
		Address: "registry.terraform.io/henrikhalt/dryad",
	})
	if err != nil {
		log.Fatal(err)
	}
}
