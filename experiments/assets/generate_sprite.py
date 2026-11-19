"""Reference-inspired Usagi sprites, 128x128, 4-bit, curious/happy (16 KiB).
Pillow is used offline only; palette matches rtl/display/usagi_display.sv.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
SIZE, SS = 128, 4
PALETTE = [
    (0,0,0), (248,230,160), (48,44,39), (242,166,172),
    (255,247,213), (229,201,120), (181,157,102), (242,172,176),
    (233,154,165), (255,255,247), (243,216,143), (224,168,160),
    (110,95,69), (208,190,134), (249,204,188), (252,238,183),
]


def make(happy):
    im=Image.new('RGBA',(SIZE*SS,SIZE*SS))
    draw=ImageDraw.Draw(im)
    def color(i): return (*PALETTE[i],255)
    def ellipse(box,fill,outline=None,width=0.65):
        draw.ellipse(tuple(round(v*SS) for v in box),fill=color(fill),
            outline=color(outline) if outline is not None else None,
            width=max(1,round(width*SS)))
    def curve(points,ink=2,width=1.35):
        n=len(points)-1
        samples=[]
        for j in range(81):
            t=j/80
            samples.append(tuple(sum(math.comb(n,k)*(1-t)**(n-k)*t**k*p[d]
                for k,p in enumerate(points))*SS for d in (0,1)))
        draw.line(samples,fill=color(ink),width=max(1,round(width*SS)),joint='curve')
        r=width*SS/2
        for x,y in (samples[0],samples[-1]):
            draw.ellipse((x-r,y-r,x+r,y+r),fill=color(ink))

    # Small body, short limbs; no contrasting white belly patch.
    ellipse((47,113,59,127),1,6)
    ellipse((70,113 if not happy else 110,83,126 if not happy else 123),1,6)
    ellipse((40,83,89,121),1,6)
    if happy:
        ellipse((28,90,43,104),1,6);ellipse((87,90,102,104),1,6)
        curve([(32,99),(33,103),(36,104)],width=0.7)
        curve([(98,99),(97,103),(94,104)],width=0.7)
    else:
        ellipse((32,90,43,111),1,6);ellipse((86,90,97,111),1,6)
    # Long upright ears with full-length pink lining.
    ellipse((46,1,59,49),1,6);ellipse((70,0,83,49),1,6)
    ellipse((48.5,4,54,43),7);ellipse((75,3,80.5,43),7)
    curve([(56,7),(57,21),(56,39)],ink=4,width=0.7)
    curve([(72,6),(72,21),(73,39)],ink=4,width=0.7)
    # Broad head dominates the silhouette.
    ellipse((19,37,109,99),1,6,width=0.75)
    curve([(30,53),(40,36),(75,35),(96,51)],ink=15,width=1.8)
    # High curved eyebrows and glossy round eyes in both expressions.
    curve([(34,59),(36,48),(43,45),(49,46)],width=1.55)
    curve([(77,45),(86,44),(94,49),(96,59)],width=1.55)
    for cx in (50,79):
        ellipse((cx-5.3,63,cx+5.3,74.3),2)
        ellipse((cx-2.4,64.5,cx+0.8,67.8),9)
        ellipse((cx+0.3,70,cx+2.3,71.5),4)
    # Pink cheeks with four diagonal ink hatches each.
    for cx in (35,94):
        ellipse((cx-8,75,cx+8,84.5),3)
        for offset in (-4.8,-1.6,1.6,4.8):
            curve([(cx+offset+0.8,77),(cx+offset-0.8,81.8)],width=0.85)
    # Central nose and the distinctive W-shaped mouth / tongue.
    ellipse((62.2,76,65.8,79.2),2)
    if happy:
        ellipse((60,80,69,90),2);ellipse((62.1,83.4,67,88.3),8)
        curve([(64.5,83.5),(64.4,85.5)],ink=2,width=0.65)
    else:
        curve([(63.5,81.8),(66.5,85),(63,87)],width=1.45)
    curve([(57,78.8),(58,84.4),(64,83),(64,78.8)],width=1.65)
    curve([(64,78.8),(64,84),(70,84),(71.5,78.5)],width=1.65)
    if happy: curve([(62.1,93),(64,94.5),(66,93)],width=1)
    small=im.resize((SIZE,SIZE),Image.Resampling.LANCZOS)
    indices=[]
    for r,g,b,a in (small.getpixel((x,y)) for y in range(SIZE) for x in range(SIZE)):
        indices.append(0 if a<128 else min(range(1,16),key=lambda i:
            sum((v-c)**2 for v,c in zip((r,g,b),PALETTE[i]))))
    return indices


def rgba(indices):
    image=Image.new('RGBA',(SIZE,SIZE))
    image.putdata([(*PALETTE[p],255 if p else 0) for p in indices])
    return image


if __name__=='__main__':
    neutral,happy=make(False),make(True)
    pixels=neutral+happy
    rom=OUT.parents[1]/'final.srcs'/'sources_1'/'rom'/'usagi_128x128.mem'
    rom.parent.mkdir(parents=True,exist_ok=True)
    rom.write_text(''.join(f'{p:x}\n' for p in pixels),encoding='ascii')
    preview=Image.new('RGB',(SIZE*8,SIZE*4),(24,35,52))
    for i,(name,indices) in enumerate((('neutral',neutral),('happy',happy))):
        art=rgba(indices);art.save(OUT/f'usagi_{name}.png')
        enlarged=art.resize((SIZE*4,SIZE*4),Image.Resampling.NEAREST)
        preview.paste(enlarged,(i*SIZE*4,0),enlarged)
    preview.save(OUT/'sprite_preview.png')
    print(f'Wrote {len(pixels)} nibbles ({len(pixels)//2} bytes ROM)')
