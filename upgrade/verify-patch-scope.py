"""Fail closed on edits outside the reviewed SUSFS integration file list."""
import hashlib,json,re,subprocess
from pathlib import Path
lock=json.loads(Path('sources.lock.json').read_text())
patch=Path('upgrade/susfs-210-to-230.patch').read_bytes()
assert hashlib.sha256(patch).hexdigest()==lock['susfs']['local_patch_sha256']
paths=re.findall(r'^diff --git a/(\S+) b/(\S+)$',patch.decode(),re.M)
allowed=set(lock['susfs']['allowed_kernel_paths'])
assert paths and all(old==new and old in allowed for old,new in paths)
assert not any(old.startswith(('include/uapi/','include/soc/')) for old,_ in paths)
changed=set(subprocess.check_output(['git','-C','src/sm8550','diff','--name-only','HEAD']).decode().splitlines())
assert changed<=allowed|{'KernelSU-Next'},sorted(changed-allowed-{'KernelSU-Next'})
subprocess.run(['git','-C','src/sm8550','diff','--exit-code','--','include/uapi','include/soc'],check=True)
result={'passed':True,'patch_sha256':hashlib.sha256(patch).hexdigest(),'reviewed_patch_paths':[p[0] for p in paths],'unrelated_uapi_headers_unchanged':True}
Path('artifacts/patch-scope-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
