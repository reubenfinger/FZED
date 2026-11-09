"""Embed the newest supplied Gills FZ factory bank without changing its bytes."""
from pathlib import Path
import base64
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[2]
GILLS = ROOT.parents[1]/'2026-09-24 Gills/referenced-chatgpt-conversation-this-is-an'
SOURCE = GILLS/'outputs/SD_CARD_PERF38H/USER_FZ.BIN'
APP = ROOT/'outputs/FZED'
data = SOURCE.read_bytes()
assert len(data)==54416 and data[:8]==b'GLUSER01'
assert struct.unpack_from('<HHH',data,8)==(4,100,544)
used = sum(data[16+i*544+13]==1 for i in range(100))
assert used==26
(APP/'USER_FZ.BIN').write_bytes(data)
metadata = {'source':'Gills SD_CARD_PERF38H/USER_FZ.BIN','slots':100,'used':used,
    'sha256':hashlib.sha256(data).hexdigest(),'base64':base64.b64encode(data).decode()}
(APP/'user-bank.js').write_text('"use strict";\nwindow.FZ_USER_BANK = '+json.dumps(metadata,separators=(',',':'))+';\n')
print(json.dumps({k:v for k,v in metadata.items() if k!='base64'}))
