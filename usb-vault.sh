#!/bin/sh
set -e

# Directory containing the vault
mydir="$(dirname "$(realpath "$0")")"
suffix=".usb-vault"
fsparam="-t ext4 -m 0"
proj="usb-vault"

## Print an error message and exit with error
# $1 Error message
vlt_die()
{
  echo "$proj: $1" 1>&2
  exit 1
}

## Print the name of the current file vault to the std. out
# $1 Name of the vault
vlt_print_path()
{
  echo "$mydir/$1$suffix"
}

## Print the name used by the device mapper
# $1 Path to the vault file
vlt_print_mapper_name()
{
  [ ! -f "$1" ] && vlt_die "File \"$1\" does not exist"
  echo "$proj-$(cryptsetup luksUUID "$1" | md5sum | head -c 10)"
  [ "$?" != 0 ] && vlt_die "File \"$1\" is not valid vault"
}

## Format vault file-system
# $1 Name of the vault to be created
# $2 Name for the device mapper
vlt_fs_format()
{
  sudo cryptsetup luksOpen "$1" "$2"
  sudo mkfs $fsparam "/dev/mapper/$2"
  sudo cryptsetup close "$2"
}

## Create a new vault file
# $1 Name of the vault to be created
# $2 Size of the vault to be created
vlt_create()
{
  [ -f "$1" ] && vlt_die "File \"$1\" already exists"

  dd if=/dev/random of="$1" bs=1M count=$2 status=none
  cryptsetup luksFormat -qy "$1"
  vlt_fs_format "$1" "$(vlt_print_mapper_name "$1")"
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
name="my"

# Handle option arguments
while getopts ":c: :n: :h" OPT
do
  case $OPT in
    c) vlt_create "$(vlt_print_path "$name")" "$OPTARG" ;;
    n) name="$OPTARG" ;;
    h) print_help; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done
