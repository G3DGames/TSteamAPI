# redistributable_bin

Copy the **contents** of `sdk/redistributable_bin` from the Steamworks SDK
**1.65** (`steamworks_sdk_165.zip`, from the Steamworks partner site) into
this folder. Everything here except this README is ignored by git: the SDK is
licensed to Steamworks partners and is not part of the repository.

After copying, the folder must look like this (this is Valve's full layout):

| Path                            | Platform          | Used by                   |
|---------------------------------|-------------------|---------------------------|
| `steam_api.dll`                 | Win32             | Delphi, FPC               |
| `steam_api.lib`                 | (C++ import lib)  | not used                  |
| `win64/steam_api64.dll`         | Win64             | Delphi, FPC               |
| `win64/steam_api64.lib`         | (C++ import lib)  | not used                  |
| `osx/libsteam_api.dylib`        | macOS x64 + ARM64 | Delphi, FPC               |
| `linux64/libsteam_api.so`       | Linux x86_64      | Delphi, FPC               |
| `linux32/libsteam_api.so`       | Linux i386        | FPC only (may be dropped) |
| `linuxarm64/libsteam_api.so`    | Linux aarch64     | FPC only                  |
| `androidarm64/libsteam_api.so`  | Android aarch64   | Delphi (Android64), FPC   |

Common mistakes: copying the folder itself into here (giving
`redistributable_bin/redistributable_bin/...`), or copying the whole `sdk/`.

## Check it

```
python3 tools/check_redist.py
```

For each library it checks that the file exists (linux32 is optional), that the binary really is
for that platform and CPU, and that it comes from SDK 1.65 (by its exports).
Output ends with `Result: all required redistributables OK` when everything
is in place; paste the output back if it reports a problem.

Two further checks happen without Python:

- **Build (Windows):** the demo projects' post-build event copies the DLL next
  to the executable, or prints a `WARNING: ... not found in redistributable_bin`
  line in the build messages.
- **Run time:** after loading the library the core logs which SDK generation
  it is from, and logs a warning if it is older than 1.65.

macOS, Linux and Android builds deploy the library from here through the
projects' Deployment entries (Android: `library\lib\arm64-v8a\`).
