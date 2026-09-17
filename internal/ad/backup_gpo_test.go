package ad

import (
	"encoding/base64"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildMigrationTableXMLEmpty(t *testing.T) {
	if xml := BuildMigrationTableXML(nil); xml != "" {
		t.Fatalf("expected empty string for no migrations, got %q", xml)
	}
}

func TestBuildMigrationTableXMLContents(t *testing.T) {
	xml := BuildMigrationTableXML([]BackupGPOMigration{
		{Source: `OLDDOMAIN\svc`, Destination: `NEWDOMAIN\svc`, Type: "User"},
		{Source: `\\old\share`, Destination: `\\new\share`, Type: "UNCPath"},
	})

	for _, want := range []string{
		`<MigrationTable xmlns="http://www.microsoft.com/GroupPolicy/GPOOperations/MigrationTable">`,
		"<Type>User</Type>",
		"<Source>OLDDOMAIN\\svc</Source>",
		"<Destination>NEWDOMAIN\\svc</Destination>",
		"<Type>UNCPath</Type>",
	} {
		if !strings.Contains(xml, want) {
			t.Fatalf("expected migration table XML to contain %q, got:\n%s", want, xml)
		}
	}
}

func TestBuildMigrationTableXMLSameAsSource(t *testing.T) {
	xml := BuildMigrationTableXML([]BackupGPOMigration{
		{Source: `AnotherGroup@utv.local`, SameAsSource: true, Type: "GlobalGroup"},
	})

	if strings.Contains(xml, "<Destination>") {
		t.Fatalf("expected no <Destination> element for a same_as_source entry, got:\n%s", xml)
	}
	if !strings.Contains(xml, "<DestinationSameAsSource>") {
		t.Fatalf("expected a <DestinationSameAsSource> element, got:\n%s", xml)
	}
}

func TestHashBackupGPOContentOrderIndependent(t *testing.T) {
	filesA := []BackupGPOFile{{Path: "a.xml", Content: "AA=="}, {Path: "b.xml", Content: "BB=="}}
	filesB := []BackupGPOFile{{Path: "b.xml", Content: "BB=="}, {Path: "a.xml", Content: "AA=="}}

	if HashBackupGPOContent(filesA, nil) != HashBackupGPOContent(filesB, nil) {
		t.Fatal("expected hash to be independent of file order")
	}

	migA := []BackupGPOMigration{{Source: "x", Destination: "y", Type: "Unknown"}}
	if HashBackupGPOContent(filesA, migA) == HashBackupGPOContent(filesA, nil) {
		t.Fatal("expected migrations to change the hash")
	}
}

func TestLoadBackupGPOFiles(t *testing.T) {
	root := t.TempDir()
	backupDir := filepath.Join(root, "MyGPO", "{9CB8219C-31FF-4A85-A7A3-9BCBB6A41D02}")
	if err := os.MkdirAll(backupDir, 0o755); err != nil {
		t.Fatalf("MkdirAll: %v", err)
	}

	if err := os.WriteFile(filepath.Join(backupDir, "Backup.xml"), []byte("<Backup/>"), 0o644); err != nil {
		t.Fatalf("WriteFile: %v", err)
	}

	files, err := LoadBackupGPOFiles(root, "MyGPO")
	if err != nil {
		t.Fatalf("LoadBackupGPOFiles: %v", err)
	}

	if len(files) != 1 {
		t.Fatalf("expected 1 file, got %d", len(files))
	}

	want := "{9CB8219C-31FF-4A85-A7A3-9BCBB6A41D02}/Backup.xml"
	if files[0].Path != want {
		t.Fatalf("expected path %q, got %q", want, files[0].Path)
	}

	decoded, err := base64.StdEncoding.DecodeString(files[0].Content)
	if err != nil {
		t.Fatalf("decoding content: %v", err)
	}
	if string(decoded) != "<Backup/>" {
		t.Fatalf("expected decoded content %q, got %q", "<Backup/>", string(decoded))
	}
}

func TestLoadBackupGPOFilesMissing(t *testing.T) {
	if _, err := LoadBackupGPOFiles(t.TempDir(), "DoesNotExist"); err == nil {
		t.Fatal("expected an error for a missing backup folder")
	}
}
