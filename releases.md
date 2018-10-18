# Releases

## 0.9.4

- Update (nominally) to *EnergyPlus 9.0*. NOTE: The FenestrationSurface:Detailed and RunPeriod objects have updated sets of input fields for *EnergyPlus 9.0*, so *Euclid 0.9.4* is **NOT** backwards-compatible with previous versions of *EnergyPlus*.

## 0.9.3

- Add support for new "Foundation" (Kiva) boundary condition.
- Update (nominally) to *EnergyPlus 8.7*. NOTE: The Daylighting:Controls object is still not yet handled correctly.

## 0.9.2

- Fix bug where OpenStudio extension was being detected as already loaded even when disabled.

## 0.9.1

- Disable (temporarily) the Daylighting:Controls tool and rendering until the new 8.6 changes are handled in the UI.
- Update (nominally) to *EnergyPlus 8.6*. NOTE: The Daylighting:Controls object has changed in 8.6 and is not yet handled correctly.
- Disable default constructions dialog prompt.
- Change behavior of text boxes in Object Info dialog so that input object fields are updated instantaneously as you type.
- Fix bug where Object Info dialog was not being updated when the selection was changed in certain ways.
- Restore check for update feature on Windows; fix check for update on Mac.
- Fix error notification feature so that it works again.
- Fix bug where surface and zone areas were no longer being displayed in Object Info dialog and measurement units were missing from other dialogs.
- Fix file type filters for open file dialogs.
- Fix bug that prevents files with bad string encodings from opening.
- Remove defunct *EnergyPlus Example File Generator* feature.
- Fix bug with window open/closed state not being saved.
- Fix creation of duplicate zones and surfaces caused by changes in Ruby API for *SketchUp 2016*.

## 0.9.0

- Initial *Euclid* release; this version is functionally identical to *Legacy OpenStudio 1.0.14*.
