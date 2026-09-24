package ad

import (
	"embed"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/bjoernf73/terraform-provider-adlc/internal/client"
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

	// Every operation runs inside a try/catch keyed to an event-log source named after the
	// operation script (without the .ps1 extension). Failures are logged to the
	// 'terraform-provider-adlc' event log on the target host and re-thrown; mutating
	// operations also log a change on success. Helpers live in common.ps1.
	body := names[len(names)-1]
	source := strings.TrimSuffix(body, ".ps1")
	fmt.Fprintf(&builder, "$scriptSource = '%s'\ntry {\n", source)
	builder.WriteString(script(body))
	if isMutatingScript(source) {
		fmt.Fprintf(&builder, "\nWrite-ADLCChange -Source $scriptSource -Message \"operation '%s' completed successfully\"\n", source)
	}
	builder.WriteString("}\ncatch {\n    Write-ADLCFailure -Source $scriptSource -ErrorRecord $_\n    throw\n}\n")

	return builder.String(), nil
}

// isMutatingScript reports whether an operation script changes AD, based on its name
// suffix. Mutating operations log a change entry on success; read-only operations only log
// on failure.
func isMutatingScript(source string) bool {
	for _, suffix := range []string{"_ensure", "_update", "_delete", "_set"} {
		if strings.HasSuffix(source, suffix) {
			return true
		}
	}

	return false
}
