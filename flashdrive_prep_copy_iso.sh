#!/usr/bin/env bash

# Copy ISOs to their target partitions

# options
iso_from='/path/directory' # ISO source directory
iso_mount='/mnt/loop' # ISO mount directory
device='/dev/sdc' # Flashdrive device
device_mount='/mnt/usb' # Flashdrive device mount directory
device_folder='iso' # Flashdrive device target ISO folder
use_rsync=1 # use 'rsync' with cheksum check instead of 'cp'

# other variables
declare -a iso_arr # ISO array
declare -a iso_unix_arr # ISO array for bootable ISOs
declare -a iso_windows_arr # ISO array for Windows ISOs
declare -a part_arr # Array of Windows partitions that were used
part_num=0 # How many partitions there are on the device
user_input=""
i=0
j=0

# Make sure essential options are set
if [[ -z $iso_from || -z $iso_mount || -z $device || -z $device_mount || -z $device_folder || -z $use_rsync ]]
then
	printf "Mount directory of ISO, partition, device or the ISO copy directory aren't set, set them and try again\n"
	exit 1
fi

# Fix filenames with spaces
# Copy output as is, replace spaces with '\ ' and re-read into the array
IFS=""
iso_arr=$(find "$iso_from" -type f -iname "*.iso" -print)
iso_arr=$( echo "$iso_arr" | sed 's/ /\ /g' )
readarray -t iso_arr < <(echo "$iso_arr")

# Let the user decide which ISO is for Windows and which isn't
for (( i=0 ; i < ${#iso_arr[@]}; i++ ))
do
	user_input=""
	while [[ $user_input != 'l' && $user_input != 'w' && $user_input != 's' ]]
	do
		printf "ISO file:  ${iso_arr[i]}\n"
		printf "'w' or 'l' for Windows/Linux ISO, 's' to skip: "
		read user_input 
	done
	
	# Add ISO to the right array
	case $user_input in
		'l')
			iso_unix_arr+=( ${iso_arr[i]} )
			;;
		'w')
			iso_windows_arr+=( ${iso_arr[i]} )
			;;
		's')
			continue
			;;
	esac
done

# Find out how mnay partitions there are on the device
part_num=$(( $(lsblk | awk "/${device/\/dev\//}/ {print \$0}" | wc -l) - 1 ))

for (( i=0; i < ${#iso_windows_arr[@]}; i++ ))
do
	printf "\n=== Where should ${iso_windows_arr[i]} be copied into?\n"
	printf "NAME\tSIZE\tLABEL\tUUID\n\n"
	lsblk -o NAME,SIZE,LABEL,UUID | awk "/${device/\/dev\//}/ {print \$0}"
	user_input=-1

	while [[ ! $user_input -gt 0 || ! $user_input -le $part_num ]]
	do
		printf "\nEnter the partition number: "
		read user_input

		# Check the partition number wasn't already used
		if [[ ! -z ${part_arr[${user_input}]} ]]
		then
			printf "\nPartition number $user_input was already used\n"
			user_input=-1
		fi
	done

	# partition array index position holds the ISO to copy into it
	part_arr[${user_input}]=${iso_windows_arr[i]}
done

if [[ ${#iso_unix_arr[@]} -ne 0 ]]
then
	user_input=-1
	printf "NAME\tSIZE\tLABEL\tUUID\n\n"
	lsblk -o NAME,SIZE,LABEL,UUID | awk "/${device/\/dev\//}/ {print \$0}"

	while [[  ! $user_input -gt 0 || ! $user_input -le $part_num ]]
	do
		printf "\n===Enter the partition number to copy the Linux ISOs into, in the $device_folder: " 
		read user_input

		# Check the partition number wasn't already used
		if [[ ! -z ${part_arr[${user_input}]} ]]
		then
			printf "\nPartition number $user_input was already used\n"
			user_input=-1
		fi
	done

	# partition array index position holds all the linux ISOs
	part_arr[${user_input}]='linux'
fi

for(( i=1; i <= $part_num; i++ ))
do
	# Copy ISOs for the linux partition
	if [[ ${part_arr[i]} = 'linux' ]]
	then
		printf "\n=== Copying Linux ISOs to ${device}${i} ===\n"
		mount "${device}${i}" "${device_mount}"
		mkdir "${device_mount}/${device_folder}"
		for(( j=0; j < ${#iso_unix_arr[@]}; j++ ))
		do
			if [[ $use_rsync -eq 1 ]]
			then
				rsync -crP --inplace "${iso_unix_arr[j]}" "${device_mount}/${device_folder}/"
			else
				cp -vr "${iso_unix_arr[j]}" "${device_mount}/${device_folder}/"
			fi
		done
		printf "\nUnmounting... This can take some time\n"
		umount "${device_mount}"
	elif [[ ! -z ${part_arr[i]} ]]
	then
		# Mount Windows ISO and copy as is to its partition
		printf "\n=== Mount & Copy Window ISO to ${device}${i} ===\n"
		mount "${device}${i}" "${device_mount}"
		mount "${part_arr[i]}" "${iso_mount}"
		if [[ $use_rsync -eq 1 ]]
			then
				rsync -crP --inplace "${iso_mount}"/ "${device_mount}/"
			else
				cp -vr "${iso_mount}"/* "${device_mount}/"
		fi
		printf "\nUnmounting... This can take some time\n"
		umount "${device_mount}" "${iso_mount}"
	fi
done

printf "\n=== DONE ===\n"

exit 0
