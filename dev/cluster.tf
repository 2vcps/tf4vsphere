
data "vsphere_datacenter" "dc" {
  name = "pksdemo"
}

data "vsphere_datastore" "datastore" {
  name          = "m70-datastore"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}
data "vsphere_resource_pool" "pool1" {
   name          = "ubt"
   datacenter_id = "${data.vsphere_datacenter.dc.id}"
 }
data "vsphere_network" "public" {
  name          = "VM"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "iscsi" {
  name          = "iSCSI"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "ubt1804"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}


resource "vsphere_virtual_machine" "k8s-ubt18" {
  name             = "dev-${count.index}"
  count            = "6"
  resource_pool_id = data.vsphere_resource_pool.pool1.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "dev"
  wait_for_guest_ip_timeout = "-1"
  wait_for_guest_net_timeout = "-1"
  enable_disk_uuid = "true"

  num_cpus = 4
  memory   = 8192
  guest_id = data.vsphere_virtual_machine.template.guest_id

  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  cdrom {
    client_device = true
  }

  network_interface {
    network_id   = data.vsphere_network.public.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }
  network_interface {
    network_id   = data.vsphere_network.iscsi.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "dev-${count.index}"
        domain    = "yourdomain"
      }
      network_interface {
        ipv4_address = "192.168.1.${120 + count.index}"
        ipv4_netmask = 24
      }
      network_interface {
        ipv4_address = "192.168.2.${120 + count.index}"
        ipv4_netmask = 24
      }

      ipv4_gateway = "192.168.1.1"
      dns_server_list = ["192.168.1.6","192.168.1.7"]
    }
  }
}

