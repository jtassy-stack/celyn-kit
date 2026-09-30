#!/usr/bin/env python3
"""Read or set the CelynKit version requirement of an app.

  celynkit_requirement.py get project.yml                 -> prints e.g. 1.16.1
  celynkit_requirement.py set project.yml 1.18.0
  celynkit_requirement.py get App.xcodeproj/project.pbxproj   (non-XcodeGen apps)
  celynkit_requirement.py set App.xcodeproj/project.pbxproj 1.18.0

project.yml: the `CelynKit:` package block with `url:` then `from:`.
project.pbxproj: `minimumVersion` of the XCRemoteSwiftPackageReference whose
repositoryURL is celyn-kit. Exactly one match is required, otherwise exit 1.
"""
import re
import sys

YML = re.compile(r'(CelynKit:\n\s+url: [^\n]*celyn-kit[^\n]*\n\s+from: *)"?([0-9][0-9.]*)"?')
PBX = re.compile(r'(repositoryURL = "[^"]*celyn-kit[^"]*";\s*requirement = \{[^}]*?minimumVersion = )"?([0-9][0-9.]*)"?')


def pattern(path):
    return YML if path.endswith((".yml", ".yaml")) else PBX


def main(argv):
    if len(argv) < 3 or argv[1] not in ("get", "set") or (argv[1] == "set" and len(argv) != 4):
        sys.exit(__doc__)
    cmd, path = argv[1], argv[2]
    src = open(path, encoding="utf-8").read()
    rx = pattern(path)
    hits = rx.findall(src)
    if len(hits) != 1:
        sys.exit(f"{path}: expected exactly one CelynKit requirement, found {len(hits)}")
    if cmd == "get":
        print(hits[0][1])
        return
    version = argv[3]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        sys.exit(f"not a plain semver version: {version}")
    open(path, "w", encoding="utf-8").write(rx.sub(lambda m: m.group(1) + version, src, count=1))


if __name__ == "__main__":
    main(sys.argv)
