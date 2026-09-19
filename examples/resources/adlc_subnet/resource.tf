resource "adlc_site" "headoffice" {
  name = "HeadOffice"
}

resource "adlc_subnet" "headoffice_lan" {
  name        = "10.42.0.0/16"
  site        = adlc_site.headoffice.name
  description = "Head office LAN"
  location    = "Oslo, Norway"
}
