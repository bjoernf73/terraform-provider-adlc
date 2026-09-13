package powershell

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"encoding/xml"
	"fmt"
	"strings"
	"unicode/utf16"
)

// maxCommandLength is the cmd.exe command line limit the WinRM shell runs under.
const maxCommandLength = 8000

func BuildCommand(powerShellPath string, script string) (string, error) {
	if strings.TrimSpace(powerShellPath) == "" {
		return "", fmt.Errorf("powershell_path must not be empty")
	}

	// -EncodedCommand inflates by 2.67x (UTF-16LE then base64), so the script is
	// gzipped and unpacked by a small stub on the remote side.
	stub, err := compressScript(script)
	if err != nil {
		return "", err
	}

	command := fmt.Sprintf(`"%s" -NoLogo -NoProfile -NonInteractive -EncodedCommand %s`, powerShellPath, encodeUTF16LEBase64(stub))
	if len(command) > maxCommandLength {
		return "", fmt.Errorf("remote command is %d characters after compression, exceeding the %d character command line limit", len(command), maxCommandLength)
	}

	return command, nil
}

func compressScript(script string) (string, error) {
	var compressed bytes.Buffer

	writer, err := gzip.NewWriterLevel(&compressed, gzip.BestCompression)
	if err != nil {
		return "", fmt.Errorf("creating gzip writer: %w", err)
	}

	if _, err := writer.Write([]byte(script)); err != nil {
		return "", fmt.Errorf("compressing script: %w", err)
	}

	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("flushing compressed script: %w", err)
	}

	return fmt.Sprintf(decompressStub, base64.StdEncoding.EncodeToString(compressed.Bytes())), nil
}

const decompressStub = `$ErrorActionPreference='Stop';` +
	`$bytes=[System.Convert]::FromBase64String('%s');` +
	`$stream=New-Object System.IO.MemoryStream(,$bytes);` +
	`$gzip=New-Object System.IO.Compression.GZipStream($stream,[System.IO.Compression.CompressionMode]::Decompress);` +
	`$reader=New-Object System.IO.StreamReader($gzip,[System.Text.Encoding]::UTF8);` +
	`$decoded=$reader.ReadToEnd();$reader.Close();` +
	`Invoke-Expression $decoded`

func encodeUTF16LEBase64(input string) string {
	utf16Data := utf16.Encode([]rune(input))
	bytes := make([]byte, 0, len(utf16Data)*2)

	for _, codeUnit := range utf16Data {
		bytes = append(bytes, byte(codeUnit), byte(codeUnit>>8))
	}

	return base64.StdEncoding.EncodeToString(bytes)
}

type clixmlMessage struct {
	Strings []clixmlString `xml:"S"`
}

type clixmlString string

func (s *clixmlString) UnmarshalText(text []byte) error {
	value := strings.TrimSpace(string(text))
	if strings.HasPrefix(value, "+ ") {
		value = "\n" + strings.TrimPrefix(value, "+ ")
	}
	*s = clixmlString(value)
	return nil
}

func DecodeCLIXML(input string) string {
	if !strings.Contains(input, "#< CLIXML") {
		return input
	}

	xmlInput := strings.ReplaceAll(input, "#< CLIXML", "")
	var message clixmlMessage

	if err := xml.Unmarshal([]byte(xmlInput), &message); err != nil {
		return input
	}

	parts := make([]string, 0, len(message.Strings))
	for _, item := range message.Strings {
		parts = append(parts, string(item))
	}

	joined := strings.Join(parts, "")
	replacer := strings.NewReplacer("_x000D_", "", "_x000A_", "")
	return strings.TrimSpace(replacer.Replace(joined))
}
