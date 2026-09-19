package main

import (
	"context"
	"log"

	"github.com/hashicorp/terraform-plugin-framework/providerserver"

	"github.com/bjoernf73/terraform-provider-adlc/internal/provider"
)

var version = "dev"

func main() {
	err := providerserver.Serve(context.Background(), provider.New(version), providerserver.ServeOpts{
		Address: "registry.terraform.io/bjoernf73/adlc",
	})
	if err != nil {
		log.Fatal(err)
	}
}
