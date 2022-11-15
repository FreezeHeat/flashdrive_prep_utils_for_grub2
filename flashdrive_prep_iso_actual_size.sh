#!/usr/bin/env bash

# Find out how much space you need for each ISO files in the unit specified

# options
mount_directory="/mnt/loop" # mounting directory
unit="MiB" # Must be compatible with 'df' tool
iso_directory="${HOME}/directory/" # Where the ISO files are

# other variables
iso_arr=0 # iso array
declare -a size_arr # file size array
i=0 # Array iterator

# check the variables are set
if [[ -z ${mount_directory} || -z ${unit} || -z ${iso_directory} ]]
then
	printf "One of the options variables weren't set, set them and try again\n"
	exit 1
fi

# populate iso array
readarray -t iso_arr <<< "$(find "$iso_directory" -type f -iname "*.iso")"

# Mount and save the size
printf "\n=== Mounting the ISO files and figuring their sizes ===\n"
umount "$mount_directory"

for (( i=0; i < ${#iso_arr[@]}; i++ )) 
do
	mount "${iso_arr[i]}" "$mount_directory"
	size_arr[i]=$(df -B "$unit" "$mount_directory" | grep -o -E "${mount_directory##*/}.*[0-9]*$unit")
	umount "$mount_directory"
done

# print the filesnames and their sizes
for (( i=0; i < ${#iso_arr[@]}; i++ ))
do
	printf "${iso_arr[i]}\n${size_arr[i]}\n\n"
done
