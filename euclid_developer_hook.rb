# Copyright (c) 2017-2020 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

####################################################
# COPY THIS FILE TO THE SKETCHUP PLUGINS DIRECTORY #
# "C:\Users\[your user name]\AppData\Roaming\SketchUp\SketchUp 2017\SketchUp\Plugins" #
####################################################

SKETCHUP_CONSOLE.show

# EDIT THIS PATH TO POINT TO YOUR WORKING COPY OF THE REPOSITORY.
$LOAD_PATH << "C:/Projects/Euclid/euclid-for-sketchup~/build/output/extension"

load("euclid.rb")
