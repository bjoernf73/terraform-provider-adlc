package provider

import (
	"context"
	"testing"

	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/schema/validator"
	"github.com/hashicorp/terraform-plugin-framework/types"
)

// sAMAccountName is hard-limited by AD to 20 characters; a config that exceeds it must
// fail at plan time with a clear error rather than surface AD's opaque one at apply time.
func TestMaxLengthValidatorRejectsOverLength(t *testing.T) {
	v := maxLength(20)

	req := validator.StringRequest{
		Path:        path.Root("sam_account_name"),
		ConfigValue: types.StringValue("this-name-is-21-chars"), // 21 characters
	}
	var resp validator.StringResponse

	v.ValidateString(context.Background(), req, &resp)

	if !resp.Diagnostics.HasError() {
		t.Fatal("expected a validation error for a 21 character value, got none")
	}
}

func TestMaxLengthValidatorAcceptsAtLimit(t *testing.T) {
	v := maxLength(20)

	req := validator.StringRequest{
		Path:        path.Root("sam_account_name"),
		ConfigValue: types.StringValue("exactly-20-characters"[:20]),
	}
	var resp validator.StringResponse

	v.ValidateString(context.Background(), req, &resp)

	if resp.Diagnostics.HasError() {
		t.Fatalf("expected no error for a 20 character value, got: %v", resp.Diagnostics)
	}
}

func TestMaxLengthValidatorIgnoresNullAndUnknown(t *testing.T) {
	v := maxLength(20)

	for name, value := range map[string]types.String{
		"null":    types.StringNull(),
		"unknown": types.StringUnknown(),
	} {
		t.Run(name, func(t *testing.T) {
			req := validator.StringRequest{
				Path:        path.Root("sam_account_name"),
				ConfigValue: value,
			}
			var resp validator.StringResponse

			v.ValidateString(context.Background(), req, &resp)

			if resp.Diagnostics.HasError() {
				t.Fatalf("expected no error for a %s value, got: %v", name, resp.Diagnostics)
			}
		})
	}
}
