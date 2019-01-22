# Copyright (c) 2017-2019 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("extensions")
require("euclid/lib/version")


extension = SketchupExtension.new("Euclid", "euclid/startup")
extension.name = "Euclid"
extension.description = "Adds building energy modeling capabilities by coupling SketchUp to various simulation engines."
extension.version = Euclid::VERSION
extension.creator = "Big Ladder Software"
extension.copyright = "2017-2019 Big Ladder Software LLC; 2008-2015 Alliance for Sustainable Energy"

Sketchup.register_extension(extension, true)
