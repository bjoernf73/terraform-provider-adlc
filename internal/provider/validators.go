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
