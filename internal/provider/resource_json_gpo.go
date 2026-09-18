package provider

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-framework/diag"
	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/int64planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/henrikhalt/terraform-provider-dryad/internal/ad"
	"github.com/henrikhalt/terraform-provider-dryad/internal/client"
)

var (
	_ resource.Resource                = &jsonGPOResource{}
	_ resource.ResourceWithConfigure   = &jsonGPOResource{}
	_ resource.ResourceWithImportState = &jsonGPOResource{}
	_ resource.ResourceWithModifyPlan  = &jsonGPOResource{}
)

func NewJsonGPOResource() resource.Resource {
	return &jsonGPOResource{}
}

type jsonGPOResource struct {
	client *client.Client
}

type jsonGPOResourceModel struct {
	ID                types.String `tfsdk:"id"`
	Path              types.String `tfsdk:"path"`
	TargetName        types.String `tfsdk:"target_name"`
	Replacements      types.Map    `tfsdk:"replacements"`
	ContentHash       types.String `tfsdk:"content_hash"`
	DistinguishedName types.String `tfsdk:"distinguished_name"`
	Domain            types.String `tfsdk:"domain"`
	Status            types.String `tfsdk:"status"`

	// Version at the time of our last import, used by ModifyPlan to detect edits made
	// outside Terraform since; Read() must never overwrite these, see planDriftReimport.
	ComputerADVersion     types.Int64 `tfsdk:"computer_ad_version"`
	ComputerSysvolVersion types.Int64 `tfsdk:"computer_sysvol_version"`
	UserADVersion         types.Int64 `tfsdk:"user_ad_version"`
	UserSysvolVersion     types.Int64 `tfsdk:"user_sysvol_version"`
}

func (r *jsonGPOResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
	resp.TypeName = req.ProviderTypeName + "_json_gpo"
}

func (r *jsonGPOResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Imports a GPO described as JSON (registry settings, security template, audit settings, " +
			"comments, scripts and Group Policy Preferences), the format produced by " +
			"[dry.module.ad](https://github.com/bjoernf73/dry.module.ad)'s `Export-GroupPolicyFromAD`. This is the second " +
			"of two ways this provider manages GPOs: `dryad_backup_gpo` imports a `Backup-GPO` folder; `dryad_json_gpo` " +
			"imports a JSON description instead, which resolves every security principal it references by name in the " +
			"target domain automatically (`####Replace[DOMAIN\\Name]` tokens), rather than needing an explicit migration " +
			"table.\n\n" +
			"GPO links (`dryad_gpo_links`), ACLs (`dryad_access_rule`) and WMI filters are deliberately out of scope: any " +
			"`LinkTargets`, `Permissions` or `WMIFilter` present in the JSON are ignored.\n\n" +
			"The JSON file is read from the machine running Terraform; the resource has no way to detect out-of-band " +
			"changes to that file between plans, so it re-imports whenever the file contents or `replacements` change, " +
			"detected via a content fingerprint. Re-importing overwrites `target_name`'s SYSVOL content in place, keeping " +
			"its GUID and existing links, so updates never delete and recreate the GPO.\n\n" +
			"A GPO exposes no content to diff against directly, so drift caused outside Terraform (someone editing the GPO " +
			"in GPMC) is detected through its AD/SysVol version counters instead: every plan re-checks them against the " +
			"version recorded at the last apply, and re-imports the JSON to overwrite the drift when they no longer match.",
		Attributes: map[string]schema.Attribute{
			"id": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "Terraform resource identifier. Equals the GPO's GUID.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"path": schema.StringAttribute{
				Required:            true,
				MarkdownDescription: "Local path, on the machine running Terraform, to the exported GPO JSON file.",
			},
			"target_name": schema.StringAttribute{
				Required:            true,
				MarkdownDescription: "Display name of the GPO to create or update in Active Directory. Overrides the JSON's own `Name`.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"replacements": schema.MapAttribute{
				Optional:    true,
				ElementType: types.StringType,
				MarkdownDescription: "Free-text replacements applied to the raw JSON before it is parsed. Each key is a bare " +
					"name (`DomainFQDN`, not `####DomainFQDN####`) - the `####` delimiters are implied, the same way Ansible " +
					"variables imply `{{ }}` - matched case-insensitively (as a substring, not a regex) anywhere in the file " +
					"and replaced with its value. This is `dry.module.ad`'s convention for values an export can't classify " +
					"automatically (a domain FQDN embedded in free text, for example). Unlike `dryad_backup_gpo`'s " +
					"`migrations`, there is no `type`: this is plain text substitution. Security principals are handled " +
					"separately and automatically, and never need an entry here.",
			},
			"content_hash": schema.StringAttribute{
				Computed: true,
				MarkdownDescription: "Fingerprint of the JSON file's contents and `replacements`, recomputed from local disk on " +
					"every plan. Not meant to be read directly; it exists so changes to the file are detected even though the " +
					"file itself is not a Terraform value.",
			},
			"distinguished_name": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "Distinguished name of the GPO container.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"domain": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "Domain the GPO belongs to.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"status": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "GPO status: `AllSettingsEnabled`, `UserSettingsDisabled`, `ComputerSettingsDisabled` or `AllSettingsDisabled`.",
			},
			"computer_ad_version": schema.Int64Attribute{
				Computed: true,
				MarkdownDescription: "Computer-side directory version at the time of the last apply. GPMC increments this on " +
					"every settings change, by any tool, so a mismatch against the live value is how this resource detects a GPO " +
					"edited outside Terraform; see `terraform plan`, which re-imports the JSON to overwrite such drift.",
				PlanModifiers: []planmodifier.Int64{
					int64planmodifier.UseStateForUnknown(),
				},
			},
			"computer_sysvol_version": schema.Int64Attribute{
				Computed:            true,
				MarkdownDescription: "Computer-side SYSVOL version at the time of the last apply. See `computer_ad_version`.",
				PlanModifiers: []planmodifier.Int64{
					int64planmodifier.UseStateForUnknown(),
				},
			},
			"user_ad_version": schema.Int64Attribute{
				Computed:            true,
				MarkdownDescription: "User-side directory version at the time of the last apply. See `computer_ad_version`.",
				PlanModifiers: []planmodifier.Int64{
					int64planmodifier.UseStateForUnknown(),
				},
			},
			"user_sysvol_version": schema.Int64Attribute{
				Computed:            true,
				MarkdownDescription: "User-side SYSVOL version at the time of the last apply. See `computer_ad_version`.",
				PlanModifiers: []planmodifier.Int64{
					int64planmodifier.UseStateForUnknown(),
				},
			},
		},
	}
}

func (r *jsonGPOResource) Configure(_ context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
	if req.ProviderData == nil {
		return
	}

	dryadClient, ok := req.ProviderData.(*client.Client)
	if !ok {
		resp.Diagnostics.AddError("Unexpected provider data type", fmt.Sprintf("Expected *client.Client, got %T", req.ProviderData))
		return
	}

	r.client = dryadClient
}

// ModifyPlan recomputes the local content fingerprint on every plan, so edits to the
// JSON file or replacements are treated as a change even though the file itself is
// never stored as a Terraform value.
func (r *jsonGPOResource) ModifyPlan(ctx context.Context, req resource.ModifyPlanRequest, resp *resource.ModifyPlanResponse) {
	if req.Plan.Raw.IsNull() {
		return
	}

	var plan jsonGPOResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	if plan.Path.IsUnknown() || plan.Replacements.IsUnknown() {
		return
	}

	replacements, diags := jsonGPOReplacementsFromMap(ctx, plan.Replacements)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}

	jsonContent, err := ad.LoadJsonGPOFile(plan.Path.ValueString())
	if err != nil {
		resp.Diagnostics.AddError("Unable to read JSON GPO file", err.Error())
		return
	}

	hash := ad.HashJsonGPOContent(jsonContent, replacements)
	resp.Diagnostics.Append(resp.Plan.SetAttribute(ctx, path.Root("content_hash"), types.StringValue(hash))...)

	r.planDriftReimport(ctx, req, resp)
}

// planDriftReimport detects a GPO changed outside Terraform since the last apply. Read()
// deliberately never touches the version watermark fields, so req.State here still holds
// the version recorded after our last import; an extra live fetch lets us compare it
// against the current version and force a re-import when they differ, which is the only
// way to revert drift Terraform has no other way to see.
func (r *jsonGPOResource) planDriftReimport(ctx context.Context, req resource.ModifyPlanRequest, resp *resource.ModifyPlanResponse) {
	if req.State.Raw.IsNull() || r.client == nil {
		return
	}

	var state jsonGPOResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	current, err := ad.ReadJsonGPO(ctx, r.client, state.ID.ValueString())
	if err != nil || !current.Exists {
		// Let the ordinary refresh pass surface the error, or the removal, instead.
		return
	}

	if current.ComputerADVersion == state.ComputerADVersion.ValueInt64() &&
		current.ComputerSysvolVersion == state.ComputerSysvolVersion.ValueInt64() &&
		current.UserADVersion == state.UserADVersion.ValueInt64() &&
		current.UserSysvolVersion == state.UserSysvolVersion.ValueInt64() {
		return
	}

	resp.Diagnostics.Append(resp.Plan.SetAttribute(ctx, path.Root("computer_ad_version"), types.Int64Value(current.ComputerADVersion))...)
	resp.Diagnostics.Append(resp.Plan.SetAttribute(ctx, path.Root("computer_sysvol_version"), types.Int64Value(current.ComputerSysvolVersion))...)
	resp.Diagnostics.Append(resp.Plan.SetAttribute(ctx, path.Root("user_ad_version"), types.Int64Value(current.UserADVersion))...)
	resp.Diagnostics.Append(resp.Plan.SetAttribute(ctx, path.Root("user_sysvol_version"), types.Int64Value(current.UserSysvolVersion))...)
}

func (r *jsonGPOResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
	var plan jsonGPOResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	gpo, err := r.ensure(ctx, plan, resp.Diagnostics)
	if err != nil {
		resp.Diagnostics.AddError("Unable to import JSON GPO", err.Error())
		return
	}
	if resp.Diagnostics.HasError() {
		return
	}

	resp.Diagnostics.Append(resp.State.Set(ctx, applyJsonGPOVersion(applyJsonGPOResult(plan, gpo), gpo))...)
}

func (r *jsonGPOResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
	var state jsonGPOResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	gpo, err := ad.ReadJsonGPO(ctx, r.client, state.ID.ValueString())
	if err != nil {
		resp.Diagnostics.AddError("Unable to read JSON GPO", err.Error())
		return
	}

	if !gpo.Exists {
		resp.State.RemoveResource(ctx)
		return
	}

	// Deliberately does not touch the version watermark: see planDriftReimport.
	resp.Diagnostics.Append(resp.State.Set(ctx, applyJsonGPOResult(state, gpo))...)
}

func (r *jsonGPOResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
	var plan jsonGPOResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	gpo, err := r.ensure(ctx, plan, resp.Diagnostics)
	if err != nil {
		resp.Diagnostics.AddError("Unable to import JSON GPO", err.Error())
		return
	}
	if resp.Diagnostics.HasError() {
		return
	}

	resp.Diagnostics.Append(resp.State.Set(ctx, applyJsonGPOVersion(applyJsonGPOResult(plan, gpo), gpo))...)
}

func (r *jsonGPOResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
	var state jsonGPOResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	if err := ad.DeleteJsonGPO(ctx, r.client, state.ID.ValueString()); err != nil {
		resp.Diagnostics.AddError("Unable to delete JSON GPO", err.Error())
	}
}

func (r *jsonGPOResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
	resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)
}

// ensure loads the JSON file from local disk and imports it. Used by both Create and
// Update, since re-running the import against an existing target GPO overwrites its
// SYSVOL content in place.
func (r *jsonGPOResource) ensure(ctx context.Context, plan jsonGPOResourceModel, diags diag.Diagnostics) (*ad.JsonGPO, error) {
	replacements, repDiags := jsonGPOReplacementsFromMap(ctx, plan.Replacements)
	diags.Append(repDiags...)
	if diags.HasError() {
		return nil, nil
	}

	jsonContent, err := ad.LoadJsonGPOFile(plan.Path.ValueString())
	if err != nil {
		return nil, err
	}

	return ad.EnsureJsonGPO(ctx, r.client, ad.JsonGPOInput{
		TargetName:   plan.TargetName.ValueString(),
		JSON:         jsonContent,
		Replacements: replacements,
	})
}

func jsonGPOReplacementsFromMap(ctx context.Context, m types.Map) (map[string]string, diag.Diagnostics) {
	if m.IsNull() || m.IsUnknown() {
		return nil, nil
	}

	var replacements map[string]string
	diags := m.ElementsAs(ctx, &replacements, false)
	return replacements, diags
}

func applyJsonGPOResult(model jsonGPOResourceModel, gpo *ad.JsonGPO) jsonGPOResourceModel {
	model.ID = types.StringValue(gpo.GUID)
	model.DistinguishedName = types.StringValue(gpo.DistinguishedName)
	model.Domain = types.StringValue(gpo.Domain)
	model.Status = types.StringValue(gpo.Status)
	return model
}

// applyJsonGPOVersion stamps the version watermark after a successful import. Only
// Create/Update should call this; Read() must leave it alone, see planDriftReimport.
func applyJsonGPOVersion(model jsonGPOResourceModel, gpo *ad.JsonGPO) jsonGPOResourceModel {
	model.ComputerADVersion = types.Int64Value(gpo.ComputerADVersion)
	model.ComputerSysvolVersion = types.Int64Value(gpo.ComputerSysvolVersion)
	model.UserADVersion = types.Int64Value(gpo.UserADVersion)
	model.UserSysvolVersion = types.Int64Value(gpo.UserSysvolVersion)
	return model
}
