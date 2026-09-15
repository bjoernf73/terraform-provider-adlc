package password

import (
	"strings"
	"testing"
	"unicode"
)

func classesPresent(s string) (hasLower, hasUpper, hasDigit, hasSymbol bool) {
	for _, r := range s {
		switch {
		case unicode.IsLower(r):
			hasLower = true
		case unicode.IsUpper(r):
			hasUpper = true
		case unicode.IsDigit(r):
			hasDigit = true
		default:
			hasSymbol = true
		}
	}
	return
}

func TestGenerateSatisfiesComplexity(t *testing.T) {
	for i := 0; i < 50; i++ {
		pw, err := Generate(24)
		if err != nil {
			t.Fatalf("Generate: %v", err)
		}

		if len(pw) != 24 {
			t.Fatalf("expected length 24, got %d", len(pw))
		}

		hasLower, hasUpper, hasDigit, hasSymbol := classesPresent(pw)
		if !hasLower || !hasUpper || !hasDigit || !hasSymbol {
			t.Fatalf("password %q missing a character class: lower=%v upper=%v digit=%v symbol=%v", pw, hasLower, hasUpper, hasDigit, hasSymbol)
		}
	}
}

func TestGenerateRejectsTooShort(t *testing.T) {
	if _, err := Generate(2); err == nil {
		t.Fatal("expected an error for a length shorter than the number of character classes")
	}
}

func TestGenerateIsRandom(t *testing.T) {
	seen := make(map[string]bool)
	for i := 0; i < 20; i++ {
		pw, err := Generate(24)
		if err != nil {
			t.Fatalf("Generate: %v", err)
		}

		if seen[pw] {
			t.Fatalf("generated the same password twice: %q", pw)
		}
		seen[pw] = true
	}
}

func TestGenerateMinimumLength(t *testing.T) {
	pw, err := Generate(4)
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}

	if len(pw) != 4 {
		t.Fatalf("expected length 4, got %d", len(pw))
	}
}

func TestGenerateNoWhitespace(t *testing.T) {
	pw, err := Generate(32)
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}

	if strings.ContainsAny(pw, " \t\n\r") {
		t.Fatalf("password contains whitespace: %q", pw)
	}
}
