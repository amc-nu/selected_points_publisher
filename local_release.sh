#!/bin/bash
# Warning: Do NOT call this script in parallel! Only one instance
# of this script may be ran at the same time
# Obtained from:
# https://gitlab.com/VictorLamoine/bloom_local_release/raw/master/bloom_local_release.bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Generate a debian package from a ROS package
# $os, $os_version, $ros_distro must be defined before calling.
# Arguments:
# $1 = Package name (package-name with dashes, no underscores!)
# $2 = CMake additional arguments (eg: '-Dmy_arg="true"')
# $3 = Ignore missing info if set to true
generate_deb()
{
  echo -e "\033[34m--------------------------------------------"
  echo -e "--------------------------------------------"
  echo -e "--------------------------------------------\033[39m"
  underscore_name="${1//\-/\_}"
  cd $underscore_name
  bloom-generate rosdebian --os-name $os --os-version $os_version --ros-distro $ros_distro
  : # Necessary otherwise the script "continues too fast"

  if [ ! -z "$2" ];
  then
    sed -i "/dh_auto_configure --/c\\\tdh_auto_configure -- ${2} \\\\" debian/rules
  fi

  if $3;
  then
    sed -i 's/dh_shlibdeps /dh_shlibdeps --dpkg-shlibdeps-params=--ignore-missing-info /g' debian/rules
  fi

  fakeroot debian/rules binary
  rm -rf debian/ obj-x86_64-linux-gnu/
  cd ..
  echo -e "\033[34m--------------------------------------------"
  echo -e "--------------------------------------------"
  echo -e "--------------------------------------------\033[39m"
}

# Checks if a debian package is installed of not
# returns 0 on success, 1 otherwise
# $ros_distro must be defined before calling.
# Arguments:
# $1 = Package name (package-name with dashes, no underscores!)
check_deb_installed()
{
  pkg_name=ros-$ros_distro-$1
  pkg_ok=$(dpkg-query -W --showformat='${Status}\n' $pkg_name | grep "install ok installed")
  if [ -z "$pkg_ok" ];
  then
    echo "$1 is not installed, aborting!"
    exit 1
  fi
}

# Install a debian package and keep it in an history of installed debian packages
# $ros_distro must be defined before calling.
installed_debs=()
install_deb()
{
  deb_file_name=$(ls "ros-$ros_distro-$1"*.deb)
  installed_debs+=("ros-$ros_distro-$1")
  dpkg -i $deb_file_name
}

# Display a list of installed debian packages (through the install_deb function)
# Packages are displayed in the reversed order of their installation
installed_deb_info()
{
  echo -ne "\033[31mTo remove installed debian packages use:\033[39m\n" \
  "\033[33msudo dpkg -r "
  # Reverse order
  for ((i=${#installed_debs[@]}-1; i>=0; i--));
  do
    echo -ne "${installed_debs[$i]} "
  done
  echo -e "\033[39m"
}

# Add custom rosdep keys in a new list file that can be later deleted with the clear_rosdep_keys() function
# $os, $ros_distro, $rosdep_yaml_name and $rosdep_list_name must be defined before calling.
# $rosdep_yaml_name and $rosdep_list_name must remain the same string in the entire calling script!
#
# The user must call 'rosdep update' manually after making all the necessary calls to this function
# eg:
# append_rosdep_key monitoring-temperature
# append_rosdep_key monitoring-water
# rosdep update
rosdep_keys=()
append_rosdep_key()
{
  rosdep_keys+=("$1")
  echo "yaml file:///etc/ros/rosdep/sources.list.d/$rosdep_yaml_name.yaml" | sudo tee /etc/ros/rosdep/sources.list.d/$rosdep_list_name.list >/dev/null
  keys=''
  for i in "${rosdep_keys[@]}"
  do
    underscore_name="${i//\-/\_}"
    keys+="$underscore_name:
    $os: [ros-$ros_distro-$i]\n"
  done
  echo -e "$keys" | sudo tee "/etc/ros/rosdep/sources.list.d/$rosdep_yaml_name.yaml" >/dev/null
}

# Clear installed rosdep keys, this will revert the rosdep keys to the original status
# $rosdep_yaml_name and $rosdep_list_name must remain the same string in the entire calling script!
clear_rosdep_keys()
{
  rm "/etc/ros/rosdep/sources.list.d/$rosdep_yaml_name.yaml"
  rm "/etc/ros/rosdep/sources.list.d/$rosdep_list_name.list"
  rosdep update
  rosdep fix-permissions
}

