package transport

import (
	"bytes"
	"context"
	"fmt"
	"strings"

	"github.com/masterzen/winrm"

	"github.com/bjoernf73/dry.module.ad/tf/terraform-provider-dryad/internal/config"
)

type winrmRunner struct {
	client   *winrm.Client
	endpoint string
	auth     string
}

func NewWinRMRunner(cfg config.Config) (Runner, error) {
	endpoint := winrm.NewEndpoint(
		cfg.Host,
		cfg.Port,
		cfg.WinRMUseTLS,
		cfg.Insecure,
		nil,
		nil,
		nil,
		cfg.Timeout,
	)

	// DefaultParameters is a package-level pointer; copy it before mutating.
	params := *winrm.DefaultParameters
	switch strings.ToLower(cfg.WinRMAuth) {
	case "", "basic":
	case "ntlm":
		params.TransportDecorator = func() winrm.Transporter {
			return &winrm.ClientNTLM{}
		}
	case "kerberos":
		proto := "http"
		if cfg.WinRMUseTLS {
			proto = "https"
		}

		spn := cfg.WinRMKerberosSPN
		if spn == "" {
			spn = fmt.Sprintf("HTTP/%s", cfg.Host)
		}

		params.TransportDecorator = func() winrm.Transporter {
			return &winrm.ClientKerberos{
				Username:  cfg.Username,
				Password:  cfg.Password,
				Realm:     cfg.WinRMKerberosRealm,
				Hostname:  cfg.Host,
				Port:      cfg.Port,
				Proto:     proto,
				SPN:       spn,
				KrbConf:   cfg.WinRMKerberosConfig,
				KrbCCache: cfg.WinRMKerberosCCache,
			}
		}
	default:
		return nil, fmt.Errorf("unsupported WinRM auth %q", cfg.WinRMAuth)
	}

	client, err := winrm.NewClientWithParameters(endpoint, cfg.Username, cfg.Password, &params)
	if err != nil {
		return nil, fmt.Errorf("creating WinRM client: %w", err)
	}

	scheme := "http"
	if cfg.WinRMUseTLS {
		scheme = "https"
	}

	auth := strings.ToLower(cfg.WinRMAuth)
	if auth == "" {
		auth = "basic"
	}

	return &winrmRunner{
		client:   client,
		endpoint: fmt.Sprintf("%s://%s:%d/wsman", scheme, cfg.Host, cfg.Port),
		auth:     auth,
	}, nil
}

func (r *winrmRunner) Run(ctx context.Context, command string, stdin string) (Result, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode, err := r.client.RunWithContextWithInput(ctx, command, &stdout, &stderr, strings.NewReader(stdin))
	result := Result{
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
		ExitCode: exitCode,
	}

	if err != nil {
		if strings.Contains(err.Error(), "401") {
			return result, fmt.Errorf("winrm authentication failed against %s using %s auth: %w", r.endpoint, r.auth, err)
		}

		return result, fmt.Errorf("winrm request to %s failed: %w", r.endpoint, err)
	}

	return result, nil
}
