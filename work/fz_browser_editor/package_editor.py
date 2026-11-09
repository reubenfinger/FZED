"""Package the split-file editor and an offline standalone HTML, with hashes."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT/'outputs/FZED'
standalone = ROOT/'outputs/FZED.html'
html = (APP/'index.html').read_text()
html = html.replace('<link rel="stylesheet" href="styles.css">', '<style>'+(APP/'styles.css').read_text()+'</style>')
scripts = ''
for name in ('lucide.min.js','profile.js','user-bank.js','editor.js'):
    html = html.replace(f'<script defer src="{name}"></script>', '')
    scripts += '<script>\n'+(APP/name).read_text().replace('</script','<\\/script')+'\n</script>\n'
standalone.write_text(html.replace('</body>',scripts+'</body>'))
profile = json.loads((APP/'profile.js').read_text().split(' = ',1)[1].rstrip(';\n'))
import os
gills = Path(os.environ.get('GILLS', str(ROOT.parent/'Gills')))
sources = {
    'Core110 patch':gills/'outputs/Gills_Controller_Core_110.axp',
    'Core110 header':gills/'outputs/gills_core110/gills_shared.h',
    'FZED source':ROOT/'outputs/FZ1_FZED.asm',
    'FZED disk':ROOT/'outputs/FZ1_FZED.img',
    'Gills user bank':gills/'outputs/SD_CARD_PERF38H/USER_FZ.BIN',
}
hashes = {label:hashlib.sha256(file.read_bytes()).hexdigest() for label,file in sources.items() if file.exists()}   # the Gills files are optional
assert hashes['FZED source']==profile['firmwareSourceSHA256']
if 'Core110 patch' in hashes: assert hashes['Core110 patch']==profile['coreSHA256']
if 'Core110 header' in hashes: assert hashes['Core110 header']==profile['headerSHA256']
if 'Gills user bank' in hashes:
    bundled,gb=(APP/'USER_FZ.BIN').read_bytes(),sources['Gills user bank'].read_bytes()
    assert bundled[:16+26*544]==gb[:16+26*544]  # the 26 Gills presets unchanged; FZED page presets follow (build_presets.py)
manifest = {'name':'FZED','target':'FZED','controller':'Core110','hardwareVerified':False,
    'browserLayoutVerified':False,'controls':len(profile['controls']),
    'profileRawValueMappings':len(profile['controls'])*128,
    'sourceSHA256':hashes,
    'sourceReview':['PERF40N READMEs and current FZED mappings cross-checked with Core110 (fzCode, fzSendCode, potSteps / stepRaw)',
        'tools40.asm STRP / ov3-ov5: parameter 88 / 89 controls 0-18 (stretch, voice pick / select, exit, chop into, freeze, capture on)',
        'matrixw.asm PARAM: CC10/11, envelope direction/rate and signed transforms',
        'matrixw.asm PARSE: CC111 selection, CC9 load, CC120/123 panic',
        'capo.asm CAPFLT/CMAP: CC23 transpose, CC33 sync, CC34 fade',
    'fx2h.asm FXMT: fifteen effect bands; Core80 fzCode remaps Ring/KS P4/P5'],
    'sourceInputs':list(sources),
    'unchangedFirmwareAndPresetBank':['Gills user bank'],
    'notInPackage':['FZED_SL_1_SOUND.syx','FZED_SL_2_MOD.syx','FZED_SL_3_SAMPLE.syx','FZED_SL_LAYOUT.json','FZED_REMOTE_SL.md']}   # ReMOTE SL files stay in the repository
(APP/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
excluded = {'SHA256SUMS.txt','Gills_Core71_FZED_Menu.zip','CORE71_VERIFICATION.json','NORM_FILTER_VERIFICATION.md','NORM_FILTER_VERIFICATION.json',*manifest['notInPackage']}
entries = {p.name:p for p in sorted(APP.iterdir()) if p.is_file() and p.name not in excluded}
entries[standalone.name]=standalone
(APP/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+name+'\n' for name,p in entries.items()))
archive = ROOT/'outputs/FZED.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for name,p in entries.items():
        z.write(p,'FZED/'+name)
    z.write(APP/'SHA256SUMS.txt','FZED/SHA256SUMS.txt')
for verification_pass in range(1,4):
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for name,p in entries.items():
            assert z.read('FZED/'+name)==p.read_bytes()
    for label,p in sources.items():
        if label in hashes: assert hashlib.sha256(p.read_bytes()).hexdigest()==hashes[label]
print(json.dumps({'archive':str(archive),'standalone':str(standalone),
    'archiveSHA256':hashlib.sha256(archive.read_bytes()).hexdigest(),
    'packageVerificationPasses':3},indent=2))
