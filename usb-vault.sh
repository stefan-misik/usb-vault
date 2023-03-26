#!/bin/sh
set -e

# Directory containing the vault
mydir="$(dirname "$(realpath "$0")")"
proj="usb-vault"
suffix=".$proj"
fsparam="-t ext4 -m 0"

## Print an error message and exit with error
# $1 Error message
vlt_die()
{
  echo "$proj: $1" 1>&2
  exit 1
}

## Print the name of the specified file vault to the std. out
# $1 Name of the vault
vlt_pth()
{
  echo "$mydir/$1$suffix"
}

## Print mount-point directory name for specified vault
# $1 Name of the vault
vlt_mdir()
{
  echo "$mydir/$1"
}

## If not exists, create mount-point directory and print its name
# $1 Name of the vault
vlt_make_mountpoint()
{
  [ ! -d "$(vlt_mdir "$1")" ] && \
    mkdir "$(vlt_mdir "$1")"
  echo "$(vlt_mdir "$1")"
}

## Print the name used by the device mapper
# $1 Name of the vault
vlt_print_mapper_name()
{
  [ ! -f "$(vlt_pth "$1")" ] &&  \
    vlt_die "File \"$(vlt_pth "$1")\" does not exist"
  echo "$proj-$1-$(cryptsetup luksUUID "$(vlt_pth "$1")" | md5sum | head -c 10)"
  [ "$?" != 0 ] &&  \
    vlt_die "File \"$(vlt_pth "$1")\" is not valid vault"
}

## Format vault file-system and mount it
# $1 Name of the vault to be created
# $2 Name for the device mapper
vlt_fs_format_and_unlock()
{
  sudo cryptsetup luksOpen "$(vlt_pth "$1")" "$2"
  sudo mkfs $fsparam "/dev/mapper/$2"
  sudo mount "/dev/mapper/$2" "$(vlt_make_mountpoint "$1")"
  sudo chown $(id -u):$(id -g) "$(vlt_mdir "$1")"
}

## Create a new vault file
# $1 Name of the vault to be created
vlt_unlock()
{
  sudo cryptsetup luksOpen "$(vlt_pth "$1")" "$(vlt_print_mapper_name "$1")"
  sudo mount "/dev/mapper/$(vlt_print_mapper_name "$1")" "$(vlt_make_mountpoint "$1")"
}

## Create a new vault file
# $1 Name of the vault to be created
vlt_lock()
{
  sudo umount "$(vlt_mdir "$1")"
  sudo cryptsetup close "$(vlt_print_mapper_name "$1")"
}

## Create a new vault file
# $1 Name of the vault to be created
# $2 Size of the vault to be created
vlt_create()
{
  [ -f "$(vlt_pth "$1")" ] &&  \
    vlt_die "File \"$(vlt_pth "$1")\" already exists"

  dd if=/dev/random of="$(vlt_pth "$1")" bs=1M count=$2 status=none
  cryptsetup luksFormat -qy "$(vlt_pth "$1")"
  vlt_fs_format_and_unlock "$1" "$(vlt_print_mapper_name "$1")"
}

print_help ()
{
  echo "Usage: $0 "
  echo "   OR: $0 -h"
  echo ""
  echo "  -h          Print this message"
  echo "  -n NAME     Specify the name of the vault"
  echo "  -c SIZE     Create new vault of specified size in MiB"
}

# Default values of control variables
name="vault"

# Handle option arguments
did_something=0
while getopts ":u :l :c: :n: :h" OPT
do
  case $OPT in
    u) vlt_unlock "$name" ; did_something=1 ;;
    l) vlt_lock "$name" ; did_something=1 ;;
    c) vlt_create "$name" "$OPTARG" ; did_something=1 ;;
    n) name="$OPTARG" ;;
    h) print_help; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

if [ "$did_something" == 0 ] ; then
  vlt_unlock "$name"
fi
