import sys,json,hashlib
from pathlib import Path
image, log, destination = map(Path,sys.argv[1:])
binary=image.read_bytes(); text=log.read_text(errors='replace')
assert binary[56:60]==b'ARMd', 'ARM64 image magic mismatch'
assert b'v3.4.2' in binary, 'KSU-Next new version missing from Image'
assert b'v2.3.0' in binary, 'SUSFS new version missing from Image'
assert '-- KernelSU-Next tag: v3.4.2' in text
assert '-- SUSFS_VERSION: v2.3.0' in text
result={'passed':True,'ksu_base_tag':'v3.4.2','ksu_scope':'plus upstream/maintainer integration commits','susfs_version':'v2.3.0','image_sha256':hashlib.sha256(binary).hexdigest(),'boot_tested':False,'phone_modified':False}
destination.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
