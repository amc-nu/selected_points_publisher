#!/bin/bash
set -ex

source local_release.sh

os=ubuntu
os_version=xenial
ros_distro=kinetic
rosdep_yaml_name="selected_points-publisher"
rosdep_list_name="40-selected-points-publisher"


append_rosdep_key selected-points-publisher
rosdep update

generate_deb selected-points-publisher
install_deb  selected-points-publisher

if [ "$1" == "" ]; then
  clear_rosdep_keys
fi


installed_deb_info