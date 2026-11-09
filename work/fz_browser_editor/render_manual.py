"""Python fallback for render_manual.cjs (same template, section-N ids) when the marked package isn't available."""
import re,markdown,pathlib
root=pathlib.Path(__file__).resolve().parents[2];app=root/'outputs/FZED'
js=(root/'work/fz_browser_editor/render_manual.cjs').read_text()
head=js[js.index('const html=`')+len('const html=`'):js.index('${headings.join')]
tail_t=js[js.index("</ul></nav>${content}"):js.index('`;\nfs.writeFileSync')]
content=markdown.markdown((app/'FZED_MANUAL.md').read_text(),extensions=['tables','fenced_code'])
heads=[];n=[0]
def h2(m):
    n[0]+=1;i='section-%d'%n[0];heads.append('<li><a href="#%s">%s</a></li>'%(i,m.group(1)));return '<h2 id="%s">%s</h2>'%(i,m.group(1))
content=re.sub(r'<h2>(.*?)</h2>',h2,content)
html=head+''.join(heads)+tail_t.replace('${content}',content)
(app/'FZED_MANUAL.html').write_text(html);(root/'outputs/FZED_MANUAL.html').write_text(html.replace('href="index.html"','href="FZED.html"'))
print('Rendered manual: %d sections'%len(heads))
