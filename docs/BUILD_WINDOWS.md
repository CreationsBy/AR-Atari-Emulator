# Windows editing, hosted iOS builds and sideloading

No local Mac, Xcode or local VM is needed. Source edits and native validation happen on Windows. Apple's device compilation happens on a hosted Mac. The iOS workflow is configured but has not been executed yet.

## 1. Open and validate the project

Open this folder in VS Code. The original Stella source is included; no Git submodule checkout is needed. Install Python 3.12+ from python.org if you do not already have it. On this computer, the existing Blender 5.2 Python also works:

```powershell
$projectPython = 'C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe'
& $projectPython scripts/verify_vendor.py
& $projectPython scripts/validate_project.py
& $projectPython -m unittest discover -s tests -v
```

For native source changes, stop any preview process first. `scripts/Build-Windows.ps1` finds Python, downloads Zig 0.13.0 into `.tools`, verifies its official SHA-256 and builds/tests the DLL. VS Code's **Build and test Windows native core** task calls it. If PowerShell does not allow local script execution, use the direct Python commands below instead of changing your system execution policy:

```powershell
& $projectPython scripts/build_native.py --zig .tools/zig-windows-x86_64-0.13.0/zig.exe --jobs 3
& $projectPython -m unittest discover -s tests -v
& $projectPython scripts/preview_server.py
```

The compiler must already have been extracted for that direct build command. Its official download and checksum are in `scripts/Build-Windows.ps1`. The source package excludes `.tools` and compiled outputs; source recipients can rebuild. A preview using an already built DLL needs only Python's standard library and a browser.

## 2. Connect your GitHub repository

The project repository is [CreationsBy/AR-Atari-Emulator](https://github.com/CreationsBy/AR-Atari-Emulator). It was confirmed public and empty when supplied. Authenticate GitHub access before the first push. GitHub-hosted macOS usage follows your account's Actions limits; consult the account's Actions billing settings.

Install [Git for Windows](https://git-scm.com/downloads/win), then reopen the VS Code terminal so Git appears on PATH. From this project folder, replacing the remote URL with the one GitHub gives you:

```powershell
git init
git add .
git commit -m "Add Stella-based Atari Diorama prototype"
git branch -M main
git remote add origin https://github.com/CreationsBy/AR-Atari-Emulator.git
git push -u origin main
```

Git may request your name/email and browser sign-in during first use. Complete those using your own account. Never paste Apple passwords, private keys or signing files into chat or commit them. The project's `.gitignore` excludes normal build caches and signing containers.

If you prefer a GUI, [GitHub Desktop](https://desktop.github.com/) can create a repository from this folder, commit it and publish it. Keep all source directories, `.github`, the original test ROM and the vendored source. Do not upload the ZIP as the repository's only file; Actions needs the extracted `.github/workflows/ios.yml` path.

## 3. Run the first unsigned build

The push to `main` starts **Build and verify iOS prototype**. You can also select **Actions → Build and verify iOS prototype → Run workflow**, choose `unsigned`, and use the default bundle identifier or your own reverse-domain identifier.

The workflow:

1. Verifies vendored source and original-ROM hashes on Linux.
2. Builds the native core, runs twelve test methods and captures evidence.
3. Starts a GitHub-hosted `macos-15` runner and records its Xcode/SDK versions.
4. Installs XcodeGen if needed and generates `ios/AtariDiorama.xcodeproj` from the checked-in YAML.
5. Cross-compiles an arm64 iOS static core with the selected SDK and iOS 16 minimum deployment target.
6. Builds an iPhone device archive, packages a conventional `Payload/AtariDiorama.app` IPA, and verifies structure and required resources.
7. Uploads the IPA, a signing-status manifest, the complete matching source ZIP, and build logs.

No signing secrets are required for `unsigned`. Its filename is **AtariDiorama-UNSIGNED-requires-resigning.ipa**. This is a package for a signing tool, not an app that can already be installed and launched.

On a green run, open the run's **Artifacts** section and download `AtariDiorama-unsigned`. Extract the downloaded artifact ZIP to find the `.ipa`. On failure, download `ios-build-logs` and inspect `xcode-archive.log`, `native-ios.log` and the result bundle. `pipefail` prevents a successful `tee` command from concealing an Xcode failure.

The first Apple compilation has not been run in this workspace. It may reveal Swift type/API or Apple toolchain issues that need correction before a green build and downloadable IPA are available.

## 4. Install with a free Apple account from Windows

Use the unsigned IPA after the remote build succeeds. [Sideloadly's official Windows instructions](https://sideloadly.io/) support free/paid Apple accounts and describe the required Apple desktop components. Follow its current instructions for the web versions of iTunes and iCloud.

1. Install Sideloadly from its official website and the Apple components it specifies.
2. Connect and unlock the iPhone with USB. Accept the phone/computer trust pairing.
3. Select the iPhone in Sideloadly and drag the unsigned `.ipa` into it.
4. Choose normal Apple-account signing, enter your account directly in Sideloadly, and complete Apple's authentication there.
5. Start signing/installing. This is the step that creates the app's real signature and provisioning profile.
6. On the iPhone, trust the developer profile if requested. For iOS 16+, enable Developer Mode when iOS requires it; the phone may restart.
7. Launch Atari Diorama, allow camera access, select the test cartridge, scan a table, and tap a detected surface.

Do not lower the app's iOS version in a signing tool. The source uses APIs requiring iOS 16 and AR-capable hardware. No JIT enabling procedure is needed for this interpreter core.

[Apple's Personal Team account documentation](https://developer.apple.com/help/account/basics/about-your-developer-account) describes seven-day provisioning and a three-app-per-device limit, plus App ID/device limits. Refresh or re-sign before expiration using the signing tool's supported workflow. Signing duration for paid accounts is bounded by the certificate and profile; it is not permanent.

Alternatively, use [AltStore Classic's official Windows setup guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), install AltServer/AltStore, then import the IPA through AltStore's My Apps import action. The guide covers Apple desktop components, USB trust, Wi-Fi sync, developer trust and Developer Mode. AltStore itself also consumes a free provisioning app slot. Its refresh mechanism needs the appropriate AltServer connection.

These installation paths are documented, not yet tested with this particular app. A packaging manifest never proves an iPhone launch succeeded.

## 5. Optional signed CI export

Use an Apple Developer Program account for a device-specific development or ad hoc profile you can manage in the developer portal. You can create the certificate request and P12 entirely on Windows. A local Mac is not necessary.

With OpenSSL (included in many Git for Windows installations), work in a private directory **outside this repository**:

```powershell
$opensslPath = 'C:\Program Files\Git\usr\bin\openssl.exe'
& $opensslPath req -new -newkey rsa:2048 -keyout apple-signing.key -out apple-signing.csr -subj '/CN=Atari Diorama Signing'
```

OpenSSL asks for a private-key passphrase. In [Apple's developer portal](https://developer.apple.com/account/): create an **Apple Development** certificate for a development build or **Apple Distribution** certificate for ad hoc, upload the CSR, and download its `.cer` file. Convert and combine the certificate with its matching private key:

```powershell
& $opensslPath x509 -inform DER -in certificate.cer -out certificate.pem
& $opensslPath pkcs12 -export -inkey apple-signing.key -in certificate.pem -out certificate.p12
```

Choose an export password for the P12. In the portal, register an explicit App ID such as `com.yourname.AtariDiorama`, register the iPhone UDID, and create/download a matching **iOS App Development** or **Ad Hoc** provisioning profile containing that device and certificate. [Apple documents device-specific ad hoc profiles here](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile).

In your GitHub repository's **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | Base64 of `certificate.p12` |
| `P12_PASSWORD` | The P12 export password |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 of the matching `.mobileprovision` |

For a file you want to paste directly into a GitHub secret field:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\PRIVATE\certificate.p12')) | Set-Clipboard
```

Repeat for the profile, using its actual private path. The workflow generates its own temporary keychain password. It derives and validates team, certificate fingerprint, profile name, bundle matching, profile expiry, device list and development/ad hoc type. It never prints private keys or passwords. A cleanup step restores the prior keychain search list and removes temporary credentials.

Run the workflow manually with `development` or `ad-hoc` and the exact bundle ID. Signed builds archive with the matching identity and export using a generated `ExportOptions.plist` (`debugging` or `release-testing` with current Xcode terminology). Keep the profile's UDID/device and expiry requirements in mind when installing. Only successful signed export supplies a signed IPA; the physical-device checklist must still be performed.

The implementation follows [GitHub's hosted Apple signing guidance](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications). Do not add signing secrets for the default unsigned/re-signing route.

## Hosted infrastructure and zero-VM option

[GitHub documents its standard hosted runners as virtual machines](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). You manage no VM yourself. If absolutely no VM may exist anywhere in the build path, use a remote **dedicated physical Mac**, such as [MacStadium bare-metal hardware](https://macstadium.com/pricing), and run a GitHub self-hosted runner directly on that machine. Choose its bare-metal service rather than a virtualization product.

For that variant, change the iOS job to `runs-on: [self-hosted, macOS, ARM64, atari-ios]`, install Apple's tools and XcodeGen on the remote physical machine, accept the SDK license as its operator, and dispatch builds to it. The Windows editing and IPA download path stays the same. Configure an Intel label/architecture if renting an Intel Mac. Arrange management/setup with the provider if you do not want to operate a remote desktop. Nothing here requires a local macOS VM.
