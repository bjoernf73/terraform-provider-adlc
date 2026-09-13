package ad

import (
	"embed"
	"encoding/base64"
	"encoding/json"
	"fmt"

	"github.com/bjoernf73/dry.module.ad/tf/terraform-provider-dryad/internal/client"
)

//go:embed scripts/*.ps1
var scripts embed.FS

func script(name string) string {
	content, err := scripts.ReadFile("scripts/" + name)
	if err != nil {
		panic(fmt.Sprintf("embedded script %q is missing: %v", name, err))
	}

	return string(content)
}

// buildScript prefixes the shared helpers, injects the inputs as a base64 JSON $payload
// and appends the operation body. Inputs are never interpolated into script text.
func buildScript(c *client.Client, common string, body string, payload map[string]any) (string, error) {
	payload["domain_controller"] = c.Config().DomainController

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("encoding script payload: %w", err)
	}

	return script(common) +
		fmt.Sprintf("\n$payloadJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%s'))\n$payload = $payloadJson | ConvertFrom-Json -ErrorAction Stop\n", base64.StdEncoding.EncodeToString(jsonPayload)) +
		script(body), nil
}
