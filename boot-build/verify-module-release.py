import json,struct,sys
from pathlib import Path
root=Path(sys.argv[1]); results=[]
for path in sorted(root.rglob('*.ko')):
    data=path.read_bytes()
    assert data[:6]==b'\x7fELF\x02\x01',str(path)
    shoff=struct.unpack_from('<Q',data,40)[0]
    size,count,index=struct.unpack_from('<HHH',data,58)
    headers=[struct.unpack_from('<IIQQQQIIQQ',data,shoff+i*size) for i in range(count)]
    strings=data[headers[index][4]:headers[index][4]+headers[index][5]]
    sections={strings[h[0]:].split(b'\0')[0].decode():data[h[4]:h[4]+h[5]] for h in headers}
    release=next(x.decode()[9:] for x in sections['.modinfo'].split(b'\0') if x.startswith(b'vermagic='))
    assert release=='5.15.197-ga62400d531bc SMP preempt mod_unload modversions aarch64',release
    results.append({'module':str(path.relative_to(root)),'vermagic':release})
assert results,'No in-tree module produced; cannot verify module vermagic'
result={'passed':True,'modules_checked':len(results),'modules':results}
Path(sys.argv[2]).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
