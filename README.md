# flashdrive_prep_utils_for_grub2
Flashdrive preparation utilities for GRUB2 based multi-boot flashdrives, they're commented with explanations.
This is an extension for the "GRUB2 Multiboot + Windows" guide at: http://assafy.rf.gd/asciidoc/grubcfg.html

* Each file has variables at the top that *must* be set
* You will probably need root permissions to run these
* You will need 'parted' to be installed, with flashdrive_prep_boot, if you use the option, you might need 'rsync' to be installed as well
* mkfs utilities must be installed for this to work
* The utilities were tested under Arch Linux, but there's not guarantee they will work for any other distribution
* There's absolutely no warranty if the utilities have caused any kind of damage to your devices
* You can report issues and I will try to fix them, you're always welcome to fork and make your own versions

WARNING: BE EXTREMELY CAREFUL NOT TO SET YOUR COMPUTER'S OWN DEVICE, YOU WILL LOSE ALL DATA ON IT

## File descriptions
*flashdrive_prep_boot.sh* - Prepare a flashdrive with GRUB2's bootloader, you must specify the size and label for each partition. It calculates the partition size for you based on your devices available storage, but you must specify the partition size for any Windows-based ISOs.

*flashdrive_prep_copy_iso.sh* - Searches for ISO files under a directory, asks you which are Linux based and which are Windows based and copies them to their partitions based on your choice.

*flashdrive_prep_filesystems_format.sh* - Formats all of the existing partitions in a device, supports FAT32, NTFS, exFAT and EXT4(without journal support)

*flashdrive_prep_iso_actual_size.sh* - Mount ISO files and find their mounted size, so it's easier to approximate how much data they'll need.
