# EnergyPlus Version Support

This directory contains version-specific EnergyPlus files needed for IDF/epJSON conversion and validation.

## Directory Structure

Each EnergyPlus version has its own directory with version numbers using dashes (e.g., `25-1-0` for version 25.1.0):

```
energyplus/
  25-1-0/
    Energy+.idd                # IDF Data Dictionary
    Energy+.schema.epJSON      # epJSON Schema with field mappings
    NewFileTemplate.idf        # Default template file
```

## Version Detection

The converter automatically detects EnergyPlus versions from files:

- **epJSON files**: Reads the `Version` object's `version_identifier` property
- **IDF files**: Parses the `Version` object at the top of the file

If no version is found, defaults to 25.1.0.

## Adding New Versions

To add support for a new EnergyPlus version:

1. Create a new directory with the version number (use dashes): `mkdir 24-2-0`
2. Add the version's files:
   - `Energy+.idd` from EnergyPlus installation
   - `Energy+.schema.epJSON` from EnergyPlus installation
   - `NewFileTemplate.idf` (optional) for new file creation
3. The converter will automatically use the correct schema based on the file's version

## Schema Usage

The JSON schema contains complete IDF→epJSON field mappings in its `legacy_idd` sections:
- Maps IDF positional fields to epJSON property names
- Defines extensible fields (like surface vertices)
- Provides validation rules and data types

This eliminates the need for external EnergyPlus executables during conversion.
