##################################################################################
# VARIABLE DEFINITIONS
##################################################################################

# Virtual Machine Settings
vm_name                             = "archlinux"
vm_guest_os_version                 = "2025.10.01"
vm_boot_wait                        = "10s"
vm_cpu_core                         = 4
vm_mem_size                         = 4096
vm_root_shutdown_command            = "sudo systemctl start poweroff.timer"
vm_disk_size                        = 60000
vm_ssh_port                         = 22
vm_ssh_timeout                      = "30m"
vm_ssh_username                     = "vagrant"
vm_ssh_password                     = "vagrant"
vm_country_code                     = "US"

# VirtualBox Settings
vbox_vm_headless                    = true
vbox_guest_additions                = "disable"
vbox_output_format                  = "ovf"

# VirtualBox Post-Processing Settings
vbox_post_cpu_core                  = 1
vbox_post_mem_size                  = 1024
vbox_post_graphics                  = "vmsvga"
vbox_post_vram                      = 256
vbox_post_accelerate_3d             = "off"
vbox_post_clipboard_mode            = "bidirectional"
