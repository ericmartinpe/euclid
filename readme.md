# *jEuclid for SketchUp*

> **This is jEuclid**, an epJSON-native fork of [Euclid](https://bigladdersoftware.com/projects/euclid/).

*jEuclid* is a free, open-source SketchUp extension for editing EnergyPlus model geometry. *jEuclid* builds on the *Legacy OpenStudio* extension for [*EnergyPlus*](https://energyplus.net) and extends the original *Euclid* with native epJSON format support. *jEuclid* supports both IDF and epJSON file formats, and is compatible with *EnergyPlus* versions **9.6 and later**.

## Features

**jEuclid enhancements:**
- Native epJSON format support with automatic IDF conversion
- Open and save files in either IDF or epJSON format seamlessly
- Compatible with *EnergyPlus 9.6* through *25.2*
- Requires *SketchUp 2017+* (Ruby 2.2.4+)

Download the [original Euclid project here](https://bigladdersoftware.com/projects/euclid/).

## Install/Uninstall

### Installing from Pre-built Package

*jEuclid* is installed using the Extension Manager in *SketchUp*:

1. Download the `.rbz` file for your platform from the releases
2. Open *SketchUp*
3. Go to **Window > Extension Manager**
4. Click the **Install Extension** button at the bottom left
5. Browse to and select the `.rbz` file
6. Click **Yes** to confirm installation

You can find [detailed instructions here](https://help.sketchup.com/en/article/3000263#install-manual) on how to install extensions manually via the Extension Manager.

To [uninstall](https://help.sketchup.com/en/article/3000264#uninstall-extension) *jEuclid*, use the Extension Manager. If you just want to temporarily turn off *jEuclid*, you can [disable and enable extensions](https://help.sketchup.com/en/article/3000264#enable-extension) using the Extension Manager.

### Building from Source

To build the `.rbz` extension package from source:

1. **Install Ruby** (Ruby 2.0 or later recommended)

2. **Install dependencies:**
   ```bash
   gem install rake
   gem install rubyzip
   ```

3. **Build the package:**
   ```bash
   # Clean previous builds (optional)
   rake clean
   
   # Build
   rake build
   ```

4. **Find the package:**
   - The `.rbz` file will be created in `build/package/`
   - Filename format: `euclid-[version]-[platform]-[commit].rbz`

5. **Install the package** using the Extension Manager instructions above

## Development

### Using the Developer Hook

For developers who want to make changes to jEuclid and test them without rebuilding the extension package each time:

1. **Copy the developer hook file** to your SketchUp Plugins directory:
   - Copy `euclid_developer_hook.rb` to:
     - Windows: `C:\Users\[your user name]\AppData\Roaming\SketchUp\SketchUp [version]\SketchUp\Plugins`
     - macOS: `~/Library/Application Support/SketchUp [version]/SketchUp/Plugins`

2. **Edit the path** in `euclid_developer_hook.rb` to point to your local repository:
   ```ruby
   $LOAD_PATH << "C:/path/to/your/jEuclid/build/output/extension"
   ```

3. **Restart SketchUp** - The extension will now load directly from your repository's build output

This approach allows you to make changes to the source code, rebuild the extension, and test the changes by simply restarting SketchUp, without needing to package and reinstall the `.rbz` file each time.

## License

See the file **license.txt**.

## Attribution

This project is a fork of [Euclid for SketchUp](https://bigladdersoftware.com/projects/euclid/), which builds on the Legacy OpenStudio extension. All original copyright notices and licenses have been preserved as required by the LGPL license.

- **Euclid for SketchUp** - Original project
- **Legacy OpenStudio** - Copyright (c) 2008-2015, Alliance for Sustainable Energy. Licensed under LGPL v2.1+

This fork (jEuclid) contains modifications and enhancements to support epJSON-native functionality while maintaining compatibility with the original project's licensing terms.