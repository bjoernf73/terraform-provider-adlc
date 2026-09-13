package ad

import (
	"embed"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/henrikhalt/terraform-provider-dryad/internal/client"
)

//go:embed scripts/*.ps1
var scripts embed.FS

const commonScript = "common.ps1"

func script(name string) string {
	content, err := scripts.ReadFile("scripts/" + name)
	if err != nil {
		panic(fmt.Sprintf("embedded script %q is missing: %v", name, err))
	}

	return string(content)
}

// buildScript concatenates the helper scripts, injects the inputs as a base64 JSON
// $payload and appends the operation body, which must be the last name given.
// Inputs are never interpolated into script text.
func buildScript(c *client.Client, payload map[string]any, names ...string) (string, error) {
	if len(names) < 2 {
		return "", fmt.Errorf("buildScript needs at least one helper script and a body")
	}

	payload["domain_controller"] = c.Config().DomainController

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("encoding script payload: %w", err)
	}

	var builder strings.Builder
	for _, name := range names[:len(names)-1] {
		builder.WriteString(script(name))
		builder.WriteString("\n")
	}

	fmt.Fprintf(&builder, "\n$payloadJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%s'))\n$payload = $payloadJson | ConvertFrom-Json -ErrorAction Stop\n", base64.StdEncoding.EncodeToString(jsonPayload))
	builder.WriteString(script(names[len(names)-1]))

	return builder.String(), nil
}
