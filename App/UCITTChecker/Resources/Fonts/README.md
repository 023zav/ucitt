# Slipstream fonts

✅ **The font files are already here** — pulled from the official open-source
repos (`Omnibus-Type/Archivo`, `JetBrains/JetBrainsMono`, both OFL licensed) and
declared in `Info.plist › UIAppFonts`.

The only thing left to do in Xcode: make sure these 12 files are **members of
the UCITTChecker target** (File Inspector → Target Membership) so they ship in
the app bundle. With XcodeGen, files under the target's `sources` path are
included automatically.

## Included files

```
Archivo-Regular.ttf      Archivo-Medium.ttf     Archivo-SemiBold.ttf
Archivo-Bold.ttf         Archivo-ExtraBold.ttf  Archivo-Black.ttf
ArchivoExpanded-Bold.ttf ArchivoExpanded-Black.ttf
JetBrainsMono-Regular.ttf JetBrainsMono-Medium.ttf
JetBrainsMono-SemiBold.ttf JetBrainsMono-Bold.ttf
```

## How they're referenced

`Theme.swift` loads each face by its **PostScript name** (verified against the
files), e.g. `Archivo-Black`, `ArchivoExpanded-Black`, `JetBrainsMono-Bold`.
This sidesteps the Expanded-width family-naming quirk (the Black instance reports
its family as "Archivo Expanded Black", not "Archivo Expanded").

> The app still builds and runs even if a face fails to load — SwiftUI falls back
> to the system font automatically. Licenses: SIL Open Font License 1.1.
