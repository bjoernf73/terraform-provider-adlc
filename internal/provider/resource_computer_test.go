package provider

import (
	"fmt"
	"testing"

	"github.com/hashicorp/terraform-plugin-testing/helper/acctest"
	"github.com/hashicorp/terraform-plugin-testing/helper/resource"
)

func TestAccComputerResource_basic(t *testing.T) {
	suffix := acctest.RandStringFromCharSet(6, acctest.CharSetAlphaNum)
	ou := "adlc-acc-comp-" + suffix
	name := "acc-c-" + suffix

	resource.Test(t, resource.TestCase{
		PreCheck:                 func() { testAccPreCheck(t) },
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: testAccComputerConfigBasic(ou, name),
				Check: resource.ComposeAggregateTestCheckFunc(
					resource.TestCheckResourceAttr("adlc_computer.test", "name", name),
					resource.TestCheckResourceAttr("adlc_computer.test", "sam_account_name", name),
					resource.TestCheckResourceAttr("adlc_computer.test", "enabled", "true"),
					resource.TestCheckResourceAttrSet("adlc_computer.test", "id"),
					resource.TestCheckResourceAttrSet("adlc_computer.test", "distinguished_name"),
					resource.TestCheckResourceAttrSet("adlc_computer.test", "sid"),
				),
			},
			{
				ResourceName:      "adlc_computer.test",
				ImportState:       true,
				ImportStateVerify: true,
			},
		},
	})
}

func TestAccComputerResource_update(t *testing.T) {
	suffix := acctest.RandStringFromCharSet(6, acctest.CharSetAlphaNum)
	ou := "adlc-acc-comp-" + suffix
	name := "acc-c-" + suffix

	resource.Test(t, resource.TestCase{
		PreCheck:                 func() { testAccPreCheck(t) },
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: testAccComputerConfigFull(ou, name, "first description", "Oslo", false, []string{"HOST/" + name}),
				Check: resource.ComposeAggregateTestCheckFunc(
					resource.TestCheckResourceAttr("adlc_computer.test", "description", "first description"),
					resource.TestCheckResourceAttr("adlc_computer.test", "location", "Oslo"),
					resource.TestCheckResourceAttr("adlc_computer.test", "enabled", "false"),
					resource.TestCheckResourceAttr("adlc_computer.test", "service_principal_names.#", "1"),
					resource.TestCheckResourceAttr("adlc_computer.test", "kerberos_encryption_type.#", "2"),
					resource.TestCheckResourceAttrSet("adlc_computer.test", "managed_by_dn"),
				),
			},
			{
				Config: testAccComputerConfigFull(ou, name, "second description", "Bergen", true, []string{"HOST/" + name, "HOST/" + name + ".contoso.local"}),
				Check: resource.ComposeAggregateTestCheckFunc(
					resource.TestCheckResourceAttr("adlc_computer.test", "description", "second description"),
					resource.TestCheckResourceAttr("adlc_computer.test", "location", "Bergen"),
					resource.TestCheckResourceAttr("adlc_computer.test", "enabled", "true"),
					resource.TestCheckResourceAttr("adlc_computer.test", "service_principal_names.#", "2"),
				),
			},
		},
	})
}

func testAccComputerConfigBasic(ou, name string) string {
	return testAccProviderConfig() + fmt.Sprintf(`
resource "adlc_organizational_unit" "test" {
  path           = %[1]q
  description    = "adlc computer acceptance test"
  delete_subtree = true
}

resource "adlc_computer" "test" {
  name = %[2]q
  path = adlc_organizational_unit.test.path
}
`, ou, name)
}

func testAccComputerConfigFull(ou, name, description, location string, enabled bool, spns []string) string {
	quoted := make([]string, len(spns))
	for i, spn := range spns {
		quoted[i] = fmt.Sprintf("%q", spn)
	}

	return testAccProviderConfig() + fmt.Sprintf(`
resource "adlc_organizational_unit" "test" {
  path           = %[1]q
  description    = "adlc computer acceptance test"
  delete_subtree = true
}

resource "adlc_group" "owner" {
  name  = "%[2]s-owner"
  path  = adlc_organizational_unit.test.path
  scope = "Global"
}

resource "adlc_computer" "test" {
  name        = %[2]q
  path        = adlc_organizational_unit.test.path
  description = %[3]q
  location    = %[4]q
  enabled     = %[5]t
  managed_by  = adlc_group.owner.distinguished_name

  service_principal_names  = [%[6]s]
  kerberos_encryption_type = ["AES128", "AES256"]
}
`, ou, name, description, location, enabled, joinTerraformList(quoted))
}

func joinTerraformList(items []string) string {
	result := ""
	for i, item := range items {
		if i > 0 {
			result += ", "
		}
		result += item
	}
	return result
}
