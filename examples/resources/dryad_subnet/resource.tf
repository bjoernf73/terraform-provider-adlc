resource "dryad_site" "headoffice" {
  name     = "HeadOffice"
  location = "Oslo, Norway"
}

resource "dryad_subnet" "headoffice_lan" {
  name        = "10.42.0.0/16"
  site        = dryad_site.headoffice.name
  description = "Head office LAN"
  location    = "Oslo, Norway"
}
