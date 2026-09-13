package powershell

import (
	"compress/gzip"
	"encoding/base64"
	"io"
	"regexp"
	"strings"
	"testing"
	"unicode/utf16"
)

func TestBuildCommandRoundTrip(t *testing.T) {
	script := strings.Repeat("Get-ADOrganizationalUnit -Identity 'OU=x,DC=example,DC=com'\n", 200)

	command, err := BuildCommand("pwsh", script)
	if err != nil {
		t.Fatalf("BuildCommand: %v", err)
	}

	if len(command) > maxCommandLength {
		t.Fatalf("command length %d exceeds limit %d", len(command), maxCommandLength)
	}

	if got := decodeStubScript(t, command); got != script {
		t.Fatal("decompressed script does not match the original")
	}
}

func TestBuildCommandRejectsEmptyPath(t *testing.T) {
	if _, err := BuildCommand("  ", "Get-Date"); err == nil {
		t.Fatal("expected an error for an empty powershell path")
	}
}

// decodeStubScript reverses BuildCommand: base64 UTF-16LE -> stub -> gzip payload.
func decodeStubScript(t *testing.T, command string) string {
	t.Helper()

	fields := strings.Fields(command)
	raw, err := base64.StdEncoding.DecodeString(fields[len(fields)-1])
	if err != nil {
		t.Fatalf("decoding command: %v", err)
	}

	codeUnits := make([]uint16, 0, len(raw)/2)
	for i := 0; i+1 < len(raw); i += 2 {
		codeUnits = append(codeUnits, uint16(raw[i])|uint16(raw[i+1])<<8)
	}

	stub := string(utf16.Decode(codeUnits))
	match := regexp.MustCompile(`FromBase64String\('([^']+)'\)`).FindStringSubmatch(stub)
	if match == nil {
		t.Fatalf("stub does not contain a base64 payload: %s", stub)
	}

	compressed, err := base64.StdEncoding.DecodeString(match[1])
	if err != nil {
		t.Fatalf("decoding payload: %v", err)
	}

	reader, err := gzip.NewReader(strings.NewReader(string(compressed)))
	if err != nil {
		t.Fatalf("opening gzip reader: %v", err)
	}
	defer reader.Close()

	decoded, err := io.ReadAll(reader)
	if err != nil {
		t.Fatalf("decompressing payload: %v", err)
	}

	return string(decoded)
}
