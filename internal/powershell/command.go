package powershell

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"encoding/xml"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf16"
)

// BuildCommand returns the remote command line, which is a fixed-size bootstrap that
// reads the real script from stdin. Keeping the script off the command line avoids the
// 8191 character cmd.exe limit that WinRM shells run under.
func BuildCommand(powerShellPath string) (string, error) {
	if strings.TrimSpace(powerShellPath) == "" {
		return "", fmt.Errorf("powershell_path must not be empty")
	}

	return fmt.Sprintf(`"%s" -NoLogo -NoProfile -NonInteractive -EncodedCommand %s`, powerShellPath, encodeUTF16LEBase64(stdinBootstrap)), nil
}

// EncodeScript compresses a script into the base64 form the bootstrap expects on stdin.
func EncodeScript(script string) (string, error) {
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

	return base64.StdEncoding.EncodeToString(compressed.Bytes()), nil
}

const stdinBootstrap = `$ErrorActionPreference='Stop';` +
	`if($null -ne $PSStyle){$PSStyle.OutputRendering='PlainText'};` +
	`$encoded=[Console]::In.ReadToEnd();` +
	`$bytes=[System.Convert]::FromBase64String($encoded.Trim());` +
	`$stream=New-Object System.IO.MemoryStream(,$bytes);` +
	`$gzip=New-Object System.IO.Compression.GZipStream($stream,[System.IO.Compression.CompressionMode]::Decompress);` +
	`$reader=New-Object System.IO.StreamReader($gzip,[System.Text.Encoding]::UTF8);` +
	`$script=$reader.ReadToEnd();$reader.Close();` +
	`Invoke-Expression $script`

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
	return cleanConsoleText(joined)
}

// clixmlEscape matches CLIXML character-reference escapes such as _x001B_ (ESC) and _x000A_
// (LF), which PowerShell emits for control characters when serializing the error stream.
var clixmlEscape = regexp.MustCompile(`_x([0-9A-Fa-f]{4})_`)

// ansiEscape matches ANSI/VT control sequences (colour codes, cursor moves) that PowerShell 7
// bakes into error records for terminal rendering.
var ansiEscape = regexp.MustCompile(`\x1b\[[0-9;]*[A-Za-z]`)

// cleanConsoleText turns CLIXML/ANSI-laden remote output into plain, readable text: it decodes
// the _xNNNN_ character escapes, then strips the ANSI colour sequences that decoding reveals.
func cleanConsoleText(input string) string {
	decoded := clixmlEscape.ReplaceAllStringFunc(input, func(match string) string {
		code, err := strconv.ParseInt(match[2:6], 16, 32)
		if err != nil {
			return match
		}
		if code == '\r' {
			return ""
		}
		return string(rune(code))
	})

	stripped := ansiEscape.ReplaceAllString(decoded, "")
	return strings.TrimSpace(stripped)
}
