package transport

import (
	"context"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/henrikhalt/terraform-provider-dryad/internal/config"
)

// Manual connectivity check. Set DRYAD_HOST, DRYAD_USERNAME and DRYAD_PASSWORD to run it:
//
//	DRYAD_HOST=10.0.13.6 DRYAD_USERNAME='UTV\Administrator' DRYAD_PASSWORD=... \
//	  go test ./internal/transport -run TestWinRMSmoke -v
func TestWinRMSmoke(t *testing.T) {
	host := os.Getenv("DRYAD_HOST")
	if host == "" {
		t.Skip("DRYAD_HOST not set")
	}

	port := 5985
	if raw := os.Getenv("DRYAD_PORT"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil {
			t.Fatalf("invalid DRYAD_PORT: %v", err)
		}
		port = parsed
	}

	auth := os.Getenv("DRYAD_WINRM_AUTH")
	if auth == "" {
		auth = "ntlm"
	}

	cfg := config.Config{
		Host:           host,
		Port:           port,
		Transport:      "winrm",
		Username:       os.Getenv("DRYAD_USERNAME"),
		Password:       os.Getenv("DRYAD_PASSWORD"),
		Insecure:       true,
		PowerShellPath: "pwsh",
		Timeout:        30 * time.Second,
		WinRMUseTLS:    os.Getenv("DRYAD_WINRM_USE_TLS") == "true",
		WinRMAuth:      auth,
	}

	runner, err := NewWinRMRunner(cfg)
	if err != nil {
		t.Fatalf("creating runner: %v", err)
	}

	result, err := runner.Run(context.Background(), "whoami", "")
	t.Logf("exit=%d stdout=%q stderr=%q", result.ExitCode, result.Stdout, result.Stderr)
	if err != nil {
		t.Fatalf("running command: %v", err)
	}
}
