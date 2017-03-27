# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("extensions")
require("euclid/lib/version")


extension = SketchupExtension.new("Euclid for CBECC-Res", "euclid/startup")
extension.name = "Euclid for CBECC-Res"
extension.description = "Adds building energy modeling capabilities by coupling SketchUp to various simulation engines."
extension.version = Euclid::VERSION
extension.creator = "Big Ladder Software"
extension.copyright = "2017 Big Ladder Software LLC; 2008-2015 Alliance for Sustainable Energy"

Sketchup.register_extension(extension, true)
