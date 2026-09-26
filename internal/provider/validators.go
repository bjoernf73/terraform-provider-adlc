package provider

import (
	"context"
	"fmt"
	"slices"
	"strings"

	"github.com/hashicorp/terraform-plugin-framework/schema/validator"
)

// oneOf validates that a string attribute matches one of the allowed values.
type oneOfValidator struct {
	allowed []string
}

func oneOf(allowed ...string) validator.String {
	return oneOfValidator{allowed: allowed}
}

func (v oneOfValidator) Description(_ context.Context) string {
	return fmt.Sprintf("value must be one of: %s", strings.Join(v.allowed, ", "))
}

func (v oneOfValidator) MarkdownDescription(ctx context.Context) string {
	return v.Description(ctx)
}

func (v oneOfValidator) ValidateString(ctx context.Context, req validator.StringRequest, resp *validator.StringResponse) {
	if req.ConfigValue.IsNull() || req.ConfigValue.IsUnknown() {
		return
	}

	if slices.Contains(v.allowed, req.ConfigValue.ValueString()) {
		return
	}

	resp.Diagnostics.AddAttributeError(
		req.Path,
		"Invalid attribute value",
		fmt.Sprintf("Attribute %s %s, got: %s", req.Path, v.Description(ctx), req.ConfigValue.ValueString()),
	)
}

var _ validator.String = oneOfValidator{}

// maxLength validates that a string attribute is at most n characters. Used for
// sAMAccountName, which AD hard-limits to 20 characters and otherwise fails with the
// unhelpful "The name provided is not a properly formed account name.".
type maxLengthValidator struct {
	max int
}

//nolint:unparam // length is a genuine parameter; sAMAccountName (20) is just the only current caller.
func maxLength(maxLen int) validator.String {
	return maxLengthValidator{max: maxLen}
}

func (v maxLengthValidator) Description(_ context.Context) string {
	return fmt.Sprintf("value must be at most %d characters", v.max)
}

func (v maxLengthValidator) MarkdownDescription(ctx context.Context) string {
	return v.Description(ctx)
}

func (v maxLengthValidator) ValidateString(ctx context.Context, req validator.StringRequest, resp *validator.StringResponse) {
	if req.ConfigValue.IsNull() || req.ConfigValue.IsUnknown() {
		return
	}

	value := req.ConfigValue.ValueString()
	if len(value) <= v.max {
		return
	}

	resp.Diagnostics.AddAttributeError(
		req.Path,
		"Invalid attribute value",
		fmt.Sprintf("Attribute %s %s, got %d characters: %q", req.Path, v.Description(ctx), len(value), value),
	)
}

var _ validator.String = maxLengthValidator{}

// gmsaSamAccountName validates a group managed service account name. AD appends a trailing
// '$' to the sAMAccountName, so a single trailing '$' the user supplies is ignored and the
// remainder must be at most max characters (19, since the stored value including '$' is
// capped at 20).
type gmsaSamAccountNameValidator struct {
	max int
}

func gmsaSamAccountName(maxLen int) validator.String {
	return gmsaSamAccountNameValidator{max: maxLen}
}

func (v gmsaSamAccountNameValidator) Description(_ context.Context) string {
	return fmt.Sprintf("value must be at most %d characters, excluding an optional trailing '$'", v.max)
}

func (v gmsaSamAccountNameValidator) MarkdownDescription(ctx context.Context) string {
	return v.Description(ctx)
}

func (v gmsaSamAccountNameValidator) ValidateString(ctx context.Context, req validator.StringRequest, resp *validator.StringResponse) {
	if req.ConfigValue.IsNull() || req.ConfigValue.IsUnknown() {
		return
	}

	value := strings.TrimSuffix(req.ConfigValue.ValueString(), "$")
	if len(value) <= v.max {
		return
	}

	resp.Diagnostics.AddAttributeError(
		req.Path,
		"Invalid attribute value",
		fmt.Sprintf("Attribute %s %s, got %d characters: %q", req.Path, v.Description(ctx), len(value), value),
	)
}

var _ validator.String = gmsaSamAccountNameValidator{}

// setValuesOneOf validates that every element of a set is one of the allowed values.
type setValuesOneOfValidator struct {
	allowed []string
}

func setValuesOneOf(allowed ...string) validator.Set {
	return setValuesOneOfValidator{allowed: allowed}
}

func (v setValuesOneOfValidator) Description(_ context.Context) string {
	return fmt.Sprintf("each value must be one of: %s", strings.Join(v.allowed, ", "))
}

func (v setValuesOneOfValidator) MarkdownDescription(ctx context.Context) string {
	return v.Description(ctx)
}

func (v setValuesOneOfValidator) ValidateSet(ctx context.Context, req validator.SetRequest, resp *validator.SetResponse) {
	if req.ConfigValue.IsNull() || req.ConfigValue.IsUnknown() {
		return
	}

	var values []string
	resp.Diagnostics.Append(req.ConfigValue.ElementsAs(ctx, &values, false)...)
	if resp.Diagnostics.HasError() {
		return
	}

	for _, value := range values {
		if !slices.Contains(v.allowed, value) {
			resp.Diagnostics.AddAttributeError(
				req.Path,
				"Invalid attribute value",
				fmt.Sprintf("Attribute %s %s, got: %s", req.Path, v.Description(ctx), value),
			)
		}
	}
}

var _ validator.Set = setValuesOneOfValidator{}
