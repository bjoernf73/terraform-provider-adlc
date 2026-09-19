# Every file under source_path is deployed recursively to the Central Store root:
# SYSVOL/<domain>/Policies/PolicyDefinitions.
resource "adlc_administrative_templates" "central_store" {
  source_path = "${path.module}/policy_definitions"
}
