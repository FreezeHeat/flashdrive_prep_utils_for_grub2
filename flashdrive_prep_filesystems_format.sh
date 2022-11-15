#!/usr/bin/env bash

# Formats all partitions on a specific filesystems

# MAKE SURE to change the variables below to your device
# Not setting this currectly could potentially delete your system
device='/dev/sdc' # flash device
declare -a filesystems
filesystems=('fat32' 'ntfs' 'ext4') # partition type from left to right

# Other variables
user_input=0
part_num=0 # how many partitions there are on the device
i=0 

# Check that variables were set
if [[ -z ${device}  ||  -z ${filesystems} ]]
then
	printf "Device and Filsystems must be specified, do so and try again\n"
	exit 1
fi

# Verify this is the correct device
printf "\n=== Please review the following before making any changes ===\n"
printf "Device: ${device}\n"
printf "=== Output of lsblk ===\n"
lsblk "${device}"
printf "\n=== YOU WILL LOSE ALL DATA ON THIS DEVICE'S PARTITIONS!!! ===\n"

while [[ "$user_input" != "y" && "$user_input" != "n" ]]
do
	printf "\nIs ${device} the correct device? y/n: "
	read user_input
done

if [[ "$user_input" = "n" ]]
then
	printf "=== Set the correct device and start the script again ===\n"	
	exit 1
fi

# Find out how mnay partitions there are on the device
part_num=$(( $(lsblk | awk "/${device/\/dev\//}/ {print \$0}" | wc -l) - 1 ))

# Check the that the number of filesystem doesn't exceed the device's partitions
if [[ ${#filesystems[@]} -gt $part_num ]]
then
	printf "\n=== You specified ${#filesystems[@]} filesystems, but there are ${part_num} partitions in the device ${device}, fix it and try again\n"
	exit 1
fi

# Create the filesystems in order from partition 1 to X
for (( i=0; i < ${#filesystems[@]}; i++ ))
do
	printf "=== Creating the filesystems for the partitions ===\n"
	printf "=== ${device}, #$(( i + 1 )), ${filesystems[i]}\n"
	case ${filesystems[i]} in
		'fat32')
			mkfs.vfat -F 32 "${device}$(( i + 1 ))"
			;;
		'ntfs')
			mkfs.ntfs -f "${device}$(( i + 1 ))"
			;;
		'exfat')
			mkfs.exfat "${device}$(( i + 1 ))"
			;;
		'ext4')
			mkfs.ext4 -O '^has_journal' "${device}$(( i + 1 ))"
			;;
	esac
done

printf "\n=== DONE ===\n"
printf "=== Please review this output of lsblk===\n"
lsblk -f $device

exit 0
