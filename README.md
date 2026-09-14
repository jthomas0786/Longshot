# LongShot

LongShot is an iPhone SwiftUI app that combines a sequence of overlapping screenshots into one continuous tall image.

## Current MVP

- Select 2–20 screenshots from Photos in order.
- Automatically detects vertical overlap between screenshots.
- Tolerates repeated fixed headers/status areas by searching for the start of scrolled content.
- Removes duplicate overlap and renders a single full-resolution output image.
- Preview, save to Photos, or share the finished image.
- Stitching is processed locally on the iPhone.

## Windows-first workflow

You do **not** need a Mac just to edit this project or validate ordinary code changes.

1. Make changes from Windows or directly in GitHub.
2. Push to `main` or open a pull request.
3. GitHub Actions runs on a hosted macOS runner.
4. The workflow installs XcodeGen, generates `LongShot.xcodeproj`, and builds the app for the iOS Simulator with code signing disabled.

The workflow file is `.github/workflows/ios-build.yml`.

## Installing on a real iPhone

A successful GitHub Actions simulator build proves the source compiles, but Apple still requires signing before an app can be installed on a physical iPhone.

For the cleanest Windows-to-iPhone path, the next distribution milestone is **TestFlight**. That requires an Apple Developer Program account plus signing credentials/App Store Connect configuration. Those credentials should be stored as encrypted GitHub Actions secrets, never committed to this repository.

Once signing is configured, this repo can be extended with a second workflow that archives and uploads LongShot to TestFlight from GitHub's macOS runner.

## Project generation

The repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the Xcode project is reproducible from text files.

On macOS:

```bash
brew install xcodegen
xcodegen generate
open LongShot.xcodeproj
```

## Best screenshot technique

1. Take the first screenshot.
2. Scroll down about 60–75% of one screen, leaving visible overlap.
3. Take the next screenshot.
4. Repeat until the bottom.
5. In LongShot, select the screenshots from top to bottom.

## Roadmap

- Manual seam correction for low-confidence matches.
- Better detection of floating/sticky UI.
- Crop and markup tools.
- Share Extension from Photos.
- Signed GitHub Actions archive + TestFlight upload.
- Evaluate supported live scrolling capture APIs where practical.
