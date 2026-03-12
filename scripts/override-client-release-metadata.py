#!/usr/bin/env python3
from pathlib import Path
import os
import re
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('packaging/linux/release-metadata.env')
text = path.read_text()

release = os.environ.get('RELEASE_LABEL_INPUT', '').strip()
deb = os.environ.get('DEB_VERSION_INPUT', '').strip()

if release:
    text, count = re.subn(
        r'^VERSION_LABEL=".*"$',
        f'VERSION_LABEL="{release}"',
        text,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit('failed to update VERSION_LABEL in release metadata')

if deb:
    text, count = re.subn(
        r'^DEB_VERSION=".*"$',
        f'DEB_VERSION="{deb}"',
        text,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit('failed to update DEB_VERSION in release metadata')

path.write_text(text)
print(path)
