
provider "vsphere" {
  user           = "jowings"
  password       = "yourpasspwod"
  vsphere_server = "vcenter"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}