package main

import (
	"context"
	"log"

	"github.com/hashicorp/terraform-plugin-framework/providerserver"

	"github.com/henrikhalt/terraform-provider-adlc/internal/provider"
)

var version = "dev"

func main() {
	err := providerserver.Serve(context.Background(), provider.New(version), providerserver.ServeOpts{
		Address: "registry.terraform.io/henrikhalt/adlc",
	})
	if err != nil {
		log.Fatal(err)
	}
}
