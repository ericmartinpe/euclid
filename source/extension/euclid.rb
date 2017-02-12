# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("extensions")
require("euclid/lib/version")


extension = SketchupExtension.new("Euclid", "euclid/lib/legacy_openstudio/lib/Startup")
extension.name = "Euclid"
extension.description = "Adds building energy modeling capabilities by coupling SketchUp to various simulation engines."
extension.version = EuclidExtension::VERSION
extension.creator = "Big Ladder Software"
extension.copyright = "2017 Big Ladder Software LLC; 2008-2015 Alliance for Sustainable Energy"

Sketchup.register_extension(extension, true)
