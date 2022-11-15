#!/usr/bin/env bash

# Creates the partitions and their filesystems based the provided options

# MAKE SURE to change the variables below to your device
# Not setting this currectly could potentially delete your system
device='/dev/sdc' # flash device
labels='WIN11 HIREN' # labels in order from left to right (1st to x) each label separated by a space
sizes='4789 3009' # specify partition sizes in the unit you specified, each partition size separated by a space
start_offset=1 # device's start offset for optimal alignment, usually 1MiB
first_label="EFI" #device's first label
unit="MiB" # Unit used to calculate size partition size (must be compatible with parted)
flashdrive_mount='/mnt/usb' # Flash device's mount point

# Other variables
capacity=0 # device's capacity in the unit specified
required_capacity=0 # how much space the iso need
total_size=0 # total size of each partition
declare -a labels_arr # labels array
declare -a sizes_arr # partition size array
declare -a from_to_arr # partition positions from and to
user_input=0
i=0 # array iterator

# Check that variables were set
if [[ -z ${device} || -z ${labels} || -z ${sizes} || -z ${start_offset} || -z ${first_label} || -z ${unit} || -z ${flashdrive_mount} ]]
then
	printf "Device, labels or sizes aren't set in the file, please re-check and try again\n"
	exit 1
fi

# Get device's capacity
capacity=$( parted ${device} unit ${unit} print | awk "/Disk.*${unit}/ {gsub (\"${unit}\",\"\",\$3); print \$3}" )

# Verify this is the correct device
printf "=== Output of lsblk ===\n"
lsblk
printf "\n=== Please review the following before making any changes ===\n"
printf "Device: ${device}\nCapacity: ${capacity}${unit}\nLabels: ${labels}\nSizes in ${unit}: ${sizes}\n"
printf "=== NOTE: The default offset for many devices is 1MiB, so you're always losing 1MiB out of the total ===\n"
printf "\n=== YOU WILL LOSE ALL DATA ON THIS DEVICE!!! ===\n"

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

# Count how many labels you've (whitespace tokenized by default)
read -a labels_arr <<< "$labels"
# Count how many sizes you've (whitespace tokenized by default)
read -a sizes_arr <<< "$sizes"

# Make sure the count of labels and sizes match
if [[ ${#labels_arr[@]} -ne ${#sizes_arr[@]} ]]
then
	printf "=== Labels count and Sizes count must match, reset them and try again ===\n"
	exit 1
fi

# Make sure the device's capacitance is less or equal to the sizes
# Also calculate the partition from and to positions (reverse order)
from_to_arr[${#labels_arr[@]}]=${capacity}
for (( i=${#sizes_arr[@]}-1; i >= 0; i-- ))
do
	total_size=$(( total_size + sizes_arr[i] ))
	from_to_arr[i]=$(( from_to_arr[i+1] - sizes_arr[i] ))
done

if [[ "$total_size" -ge "$(( capacity - 1 ))" ]]
then
	printf "Partitions total size: ${total_size}${unit}, Capacity: ${capacity}${unit}\n"
	printf "Partition size can't be bigger than the capacity\n"
	printf "Also, the first partition must be at least 1MiB and should start from 1MiB\n"
	exit 1
fi

# Print the parition layout and make sure it's correct
printf "\n=== First partition is always from 0%% and is labeled EFI\n"
printf "\n=== Partition #1\n"
printf "Label: $first_label\nSize: $(( capacity - total_size - start_offset ))${unit}\n"
printf "from: ${start_offset}${unit} to: ${from_to_arr[0]}${unit}\n"

for (( i=0; i < ${#labels_arr[@]}; i++ ))
do
	printf "\n=== Partition #$(( i + 2 ))\n"
	printf "Label: ${labels_arr[i]}\nSize: ${sizes_arr[i]}${unit}\n"
	printf "from: ${from_to_arr[i]}${unit} to: ${from_to_arr[i+1]}${unit}\n"
done

printf "\n=== Is the partition layout correct? y/n: "
read user_input
if [[ user_input = "n" ]]
then
	printf "=== Please fix the partition sizes and try again ===\n"
	exit 1
fi

# Create a new partition table and its first partition
printf "=== Destroying the partition table and any files stored on the device ===\n"
parted ${device} -a optimal mklabel msdos
# Create the first boot partition and set its flags
printf "=== Label $first_label, Size $((capacity - total_size))${unit} ===\n"
printf "=== ${device}, #1, FAT32, 0%% - ${from_to_arr[0]}, flags: esp, boot\n"
parted ${device} mkpart primary fat32 '0%' "${from_to_arr[0]}${unit}"
parted ${device} set 1 esp on
parted ${device} set 1 boot on

# Create the rest of the partitions
for (( i=1; i < ${#from_to_arr[@]}-1; i++ ))
do
	printf "=== Label ${labels_arr[i-1]}, Size ${sizes_arr[i-1]}${unit} ===\n"
	printf "=== ${device}, #$(( i + 1 )), NTFS, ${from_to_arr[i-1]} to ${from_to_arr[i]}\n"
	parted ${device} mkpart primary ntfs "${from_to_arr[i-1]}${unit}" "${from_to_arr[i]}${unit}"
done

printf "=== Label ${labels_arr[i-1]}, Size ${sizes_arr[i-1]}${unit} ===\n"
printf "=== ${device}, #$(( i + 1 )), NTFS, ${from_to_arr[i-1]} to ${from_to_arr[i]}\n"
parted ${device} mkpart primary ntfs "${from_to_arr[i-1]}${unit}" "100%"

# Create the filesystems for the paritions
printf "=== Creating the filesystems for the partitions ===\n"
# FAT32 fileysystem for boot partition
# -F specifies the type of FATs, we want 32 bit
# -v for verbose output (if any errors happen)
mkfs.fat -F 32 -n "${first_label}" "${device}1"

# NTFS filesystems, Windows-based ISO
# -f is used for fast format
# -v for verbose output (if any errors happen)
for (( i=0; i < ${#labels_arr[@]}; i++ ))
do
	mkfs.ntfs -f -L "${labels_arr[i]}" "${device}$(( i + 2 ))"
done

# Installing GRUB's bootloader to the first partition
printf "\n=== Installing GRUB's bootloader on the boot partition ===\n"
mount "${device}1" "$flashdrive_mount"
mkdir "${flashdrive_mount}/boot"
grub-install --target=i386-pc --recheck --boot-directory="${flashdrive_mount}/boot" "$device"
grub-install --target=x86_64-efi --recheck --removable --efi-directory="${flashdrive_mount}" --boot-directory="${flashdrive_mount}/boot"
umount "$flashdrive_mount"

printf "\n=== DONE ===\n"
printf "=== Please review this output of lsblk===\n"
lsblk -f $device
