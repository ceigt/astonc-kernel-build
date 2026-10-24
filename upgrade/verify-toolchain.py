"""Verify all extracted toolchain files against the pinned official Git tree."""
import hashlib, json, os, stat, sys
from pathlib import Path

def git_hash(kind, content):
    return hashlib.sha1(f'{kind} {len(content)}\0'.encode()+content).digest()

def tree_hash(directory):
    entries=[]
    for path in directory.iterdir():
        mode=path.lstat().st_mode
        name=os.fsencode(path.name)
        if stat.S_ISLNK(mode):
            value=git_hash('blob',os.fsencode(os.readlink(path)))
            gitmode=b'120000'
            sortkey=name
        elif stat.S_ISDIR(mode):
            value=tree_hash(path)
            gitmode=b'40000'
            sortkey=name+b'/'
        elif stat.S_ISREG(mode):
            h=hashlib.sha1(f'blob {path.stat().st_size}\0'.encode())
            with path.open('rb') as handle:
                for chunk in iter(lambda:handle.read(1024*1024),b''):
                    h.update(chunk)
            value=h.digest()
            gitmode=b'100755' if mode & stat.S_IXUSR else b'100644'
            sortkey=name
        else:
            raise SystemExit(f'Unexpected file type: {path}')
        entries.append((sortkey,gitmode+b' '+name+b'\0'+value))
    return git_hash('tree',b''.join(value for _,value in sorted(entries)))

if __name__=='__main__':
    lock=json.loads(Path('sources.lock.json').read_text())
    expected=lock['toolchain']['content_tree_sha1']
    actual=tree_hash(Path('toolchain/clang')).hex()
    result={'passed':actual==expected,'expected_official_tree':expected,'actual_tree':actual,'official_commit':lock['toolchain']['commit'],'scope':'All file bytes, symlink targets, executable bits and names; compressed archive metadata is excluded.'}
    Path('artifacts/toolchain-content-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if actual!=expected:
        raise SystemExit('Official toolchain content tree mismatch')
