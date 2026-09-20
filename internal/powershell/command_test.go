package powershell

import (
	"compress/gzip"
	"encoding/base64"
	"io"
	"strings"
	"testing"
	"unicode/utf16"
)

func TestBuildCommandIsConstantSize(t *testing.T) {
	small, err := BuildCommand("pwsh")
	if err != nil {
		t.Fatalf("BuildCommand: %v", err)
	}

	// cmd.exe caps the command line at 8191 characters; the script travels on stdin.
	if len(small) > 2000 {
		t.Fatalf("command line grew to %d characters", len(small))
	}
}

func TestBuildCommandRejectsEmptyPath(t *testing.T) {
	if _, err := BuildCommand("  "); err == nil {
		t.Fatal("expected an error for an empty powershell path")
	}
}

func TestEncodeScriptRoundTrip(t *testing.T) {
	script := strings.Repeat("Get-ADOrganizationalUnit -Identity 'OU=x,DC=example,DC=com'\n", 500)

	encoded, err := EncodeScript(script)
	if err != nil {
		t.Fatalf("EncodeScript: %v", err)
	}

	compressed, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		t.Fatalf("decoding payload: %v", err)
	}

	reader, err := gzip.NewReader(strings.NewReader(string(compressed)))
	if err != nil {
		t.Fatalf("opening gzip reader: %v", err)
	}
	defer func() { _ = reader.Close() }()

	decoded, err := io.ReadAll(reader)
	if err != nil {
		t.Fatalf("decompressing payload: %v", err)
	}

	if string(decoded) != script {
		t.Fatal("decompressed script does not match the original")
	}
}

func TestBootstrapReadsStdin(t *testing.T) {
	command, err := BuildCommand("pwsh")
	if err != nil {
		t.Fatalf("BuildCommand: %v", err)
	}

	fields := strings.Fields(command)
	raw, err := base64.StdEncoding.DecodeString(fields[len(fields)-1])
	if err != nil {
		t.Fatalf("decoding command: %v", err)
	}

	codeUnits := make([]uint16, 0, len(raw)/2)
	for i := 0; i+1 < len(raw); i += 2 {
		codeUnits = append(codeUnits, uint16(raw[i])|uint16(raw[i+1])<<8)
	}

	if bootstrap := string(utf16.Decode(codeUnits)); !strings.Contains(bootstrap, "[Console]::In.ReadToEnd()") {
		t.Fatalf("bootstrap does not read stdin: %s", bootstrap)
	}
}
