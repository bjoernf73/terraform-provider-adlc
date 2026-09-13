package provider

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringdefault"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/schema/validator"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/henrikhalt/terraform-provider-dryad/internal/ad"
	"github.com/henrikhalt/terraform-provider-dryad/internal/client"
)

var (
	_ resource.Resource                = &groupResource{}
	_ resource.ResourceWithConfigure   = &groupResource{}
	_ resource.ResourceWithImportState = &groupResource{}
)

func NewGroupResource() resource.Resource {
	return &groupResource{}
}

type groupResource struct {
	client *client.Client
}

type groupResourceModel struct {
	ID                types.String `tfsdk:"id"`
	Name              types.String `tfsdk:"name"`
	SamAccountName    types.String `tfsdk:"sam_account_name"`
	Path              types.String `tfsdk:"path"`
	Description       types.String `tfsdk:"description"`
	Category          types.String `tfsdk:"category"`
	Scope             types.String `tfsdk:"scope"`
	DistinguishedName types.String `tfsdk:"distinguished_name"`
	SID               types.String `tfsdk:"sid"`
}

func (r *groupResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
	resp.TypeName = req.ProviderTypeName + "_group"
}

func (r *groupResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Manages an Active Directory group by executing PowerShell on a remote Windows host.",
		Attributes: map[string]schema.Attribute{
			"id": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "Terraform resource identifier. Equals the group `objectGUID`, which is stable across renames and moves.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"name": schema.StringAttribute{
				Required:            true,
				MarkdownDescription: "Group name (the `CN`). Changing this renames the group in place.",
			},
			"sam_account_name": schema.StringAttribute{
				Optional:            true,
				Computed:            true,
				MarkdownDescription: "Pre-Windows 2000 group name. Defaults to `name`.",
			},
			"path": schema.StringAttribute{
				Required:            true,
				MarkdownDescription: "Container holding the group. Either a slash-delimited OU path relative to the domain root (`Contoso/Groups`) or a full container DN (`CN=Users,DC=contoso,DC=local`). Changing this moves the group.",
			},
			"description": schema.StringAttribute{
				Optional:            true,
				MarkdownDescription: "Group description.",
			},
			"category": schema.StringAttribute{
				Optional:            true,
				Computed:            true,
				Default:             stringdefault.StaticString("Security"),
				MarkdownDescription: "Group category: `Security` or `Distribution`.",
				Validators: []validator.String{
					oneOf("Security", "Distribution"),
				},
			},
			"scope": schema.StringAttribute{
				Optional:            true,
				Computed:            true,
				Default:             stringdefault.StaticString("Global"),
				MarkdownDescription: "Group scope: `DomainLocal`, `Global` or `Universal`.",
				Validators: []validator.String{
					oneOf("DomainLocal", "Global", "Universal"),
				},
			},
			"distinguished_name": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "Distinguished name of the group. Changes when the group is renamed or moved.",
			},
			"sid": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "Security identifier of the group.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
		},
	}
}

func (r *groupResource) Configure(_ context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
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

func (r *groupResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
	var plan groupResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	group, err := ad.EnsureGroup(ctx, r.client, groupInput(plan))
	if err != nil {
		resp.Diagnostics.AddError("Unable to create group", err.Error())
		return
	}

	resp.Diagnostics.Append(resp.State.Set(ctx, groupState(group))...)
}

func (r *groupResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
	var state groupResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	group, err := ad.ReadGroup(ctx, r.client, state.ID.ValueString())
	if err != nil {
		resp.Diagnostics.AddError("Unable to read group", err.Error())
		return
	}

	if !group.Exists {
		resp.State.RemoveResource(ctx)
		return
	}

	resp.Diagnostics.Append(resp.State.Set(ctx, groupState(group))...)
}

func (r *groupResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
	var plan groupResourceModel
	var state groupResourceModel

	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	group, err := ad.UpdateGroup(ctx, r.client, state.ID.ValueString(), groupInput(plan))
	if err != nil {
		resp.Diagnostics.AddError("Unable to update group", err.Error())
		return
	}

	resp.Diagnostics.Append(resp.State.Set(ctx, groupState(group))...)
}

func (r *groupResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
	var state groupResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	if err := ad.DeleteGroup(ctx, r.client, state.ID.ValueString()); err != nil {
		resp.Diagnostics.AddError("Unable to delete group", err.Error())
	}
}

func (r *groupResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
	resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)
}

func groupInput(model groupResourceModel) ad.GroupInput {
	samAccountName := model.SamAccountName.ValueString()
	if model.SamAccountName.IsNull() || model.SamAccountName.IsUnknown() {
		samAccountName = model.Name.ValueString()
	}

	return ad.GroupInput{
		Name:           model.Name.ValueString(),
		SamAccountName: samAccountName,
		Path:           model.Path.ValueString(),
		Description:    optionalString(model.Description),
		Category:       model.Category.ValueString(),
		Scope:          model.Scope.ValueString(),
	}
}

func groupState(group *ad.Group) groupResourceModel {
	return groupResourceModel{
		ID:                types.StringValue(group.GUID),
		Name:              types.StringValue(group.Name),
		SamAccountName:    types.StringValue(group.SamAccountName),
		Path:              types.StringValue(group.Path),
		Description:       stringPointerToTerraform(group.Description),
		Category:          types.StringValue(group.Category),
		Scope:             types.StringValue(group.Scope),
		DistinguishedName: types.StringValue(group.DistinguishedName),
		SID:               types.StringValue(group.SID),
	}
}
