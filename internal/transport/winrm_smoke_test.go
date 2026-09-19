package transport

import (
	"context"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/henrikhalt/terraform-provider-adlc/internal/config"
)

// Manual connectivity check. Set ADLC_HOST, ADLC_USERNAME and ADLC_PASSWORD to run it:
//
//	ADLC_HOST=10.0.13.6 ADLC_USERNAME='UTV\Administrator' ADLC_PASSWORD=... \
//	  go test ./internal/transport -run TestWinRMSmoke -v
func TestWinRMSmoke(t *testing.T) {
	host := os.Getenv("ADLC_HOST")
	if host == "" {
		t.Skip("ADLC_HOST not set")
	}

	port := 5985
	if raw := os.Getenv("ADLC_PORT"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil {
			t.Fatalf("invalid ADLC_PORT: %v", err)
		}
		port = parsed
	}

	auth := os.Getenv("ADLC_WINRM_AUTH")
	if auth == "" {
		auth = "ntlm"
	}

	cfg := config.Config{
		Host:           host,
		Port:           port,
		Transport:      "winrm",
		Username:       os.Getenv("ADLC_USERNAME"),
		Password:       os.Getenv("ADLC_PASSWORD"),
		Insecure:       true,
		PowerShellPath: "pwsh",
		Timeout:        30 * time.Second,
		WinRMUseTLS:    os.Getenv("ADLC_WINRM_USE_TLS") == "true",
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
