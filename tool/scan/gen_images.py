"""Makes test photos of Sudoku grids (rotation, perspective, shadows, glare,
curvature, low resolution, JPEG damage) with known answers, for checking
web/scan/scan.js. See README.md."""
import os, random, math, json, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
import numpy as np
SEED = int(os.environ.get('SEED', 11))
OUT = os.environ.get('OUT', 'images')
os.makedirs(OUT, exist_ok=True)
random.seed(SEED); np.random.seed(SEED)
puzzles = ['530070000600195000098000060800060003400803001700020006060000280000419005000080079',
 '000000000000003085001020000000507000004000100090000000500000073002010000000040009',
 '030150000567030008902000000006003890350000601001796502693805100145300080728060050',
 '003020600900305001001806400008102900700000008006708200002609500800203009005010300']
fonts=['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf','/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf']
def grid(text, fontpath, cell=70, ink=25, border=4):
    n=cell*9+10
    im=Image.new('RGB',(n,n),(250,248,240)); d=ImageDraw.Draw(im)
    f=ImageFont.truetype(fontpath,int(cell*0.62))
    for i in range(10):
        w=border if i%3==0 else 1
        p=5+i*cell
        d.line([(p,5),(p,5+9*cell)],fill=(30,30,30),width=w); d.line([(5,p),(5+9*cell,p)],fill=(30,30,30),width=w)
    for i,ch in enumerate(text):
        if ch=='0': continue
        r,c=divmod(i,9)
        d.text((5+c*cell+cell/2,5+r*cell+cell/2),ch,font=f,fill=(ink,ink,ink+10),anchor='mm')
    return im
def on_page(im, scale=1.5, color=(222,214,190)):
    n=im.size[0]; W=int(n*scale)
    bg=Image.new('RGB',(W,W),color); bd=ImageDraw.Draw(bg)
    f=ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',22)
    for k in range(14): # nearby newspaper text
        bd.text((10,10+k*14),'lorem ipsum dolor sit amet consectetur '*3,font=ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',12),fill=(80,80,80))
    off=((W-n)//2,(W-n)//2)
    bg.paste(im,off)
    return bg
def rotate(im,a): return im.rotate(a,resample=Image.BICUBIC,fillcolor=(222,214,190))
def persp(im,k):
    w,h=im.size
    coeffs=(1,k,0, 0,1,0, k/w*0.8,k/h*0.4)
    return im.transform(im.size,Image.PERSPECTIVE,coeffs,Image.BICUBIC,fillcolor=(222,214,190))
def curve(im,amp):
    a=np.array(im); h,w,_=a.shape
    out=np.zeros_like(a)
    for x in range(w):
        dy=int(amp*math.sin(math.pi*x/w))
        out[:,x]=np.roll(a[:,x],dy,axis=0)
    return Image.fromarray(out)
def shadow(im,strength):
    a=np.array(im).astype(float); h,w,_=a.shape
    X,Y=np.meshgrid(np.linspace(0,1,w),np.linspace(0,1,h))
    m=1-strength*np.clip(X*1.2+Y*0.3-0.3,0,1)
    return Image.fromarray(np.clip(a*m[...,None],0,255).astype('uint8'))
def blobshadow(im,strength):
    a=np.array(im).astype(float); h,w,_=a.shape
    X,Y=np.meshgrid(np.arange(w),np.arange(h))
    cx,cy=w*0.7,h*0.35
    m=1-strength*np.exp(-(((X-cx)/(w*0.25))**2+((Y-cy)/(h*0.18))**2))
    return Image.fromarray(np.clip(a*m[...,None],0,255).astype('uint8'))
def glare(im,strength):
    a=np.array(im).astype(float); h,w,_=a.shape
    X,Y=np.meshgrid(np.arange(w),np.arange(h))
    cx,cy=w*0.35,h*0.4
    g=strength*255*np.exp(-(((X-cx)/(w*0.12))**2+((Y-cy)/(h*0.12))**2))
    return Image.fromarray(np.clip(a+g[...,None],0,255).astype('uint8'))
def noise(im,s):
    a=np.array(im).astype(float)+np.random.normal(0,s,np.array(im).shape)
    return Image.fromarray(np.clip(a,0,255).astype('uint8'))
cases={}
def save(name,im,text,q=75):
    im.convert('RGB').save(f'{OUT}/{name}.jpg',quality=q); cases[name]=text
for pi,t in enumerate(puzzles):
    fp=fonts[pi%4]
    base=grid(t,fp)
    save(f'p{pi}_rot10',blobshadow(rotate(on_page(base),10),0.0),t)
    save(f'p{pi}_rot-12',rotate(on_page(base),-12),t)
    save(f'p{pi}_persp',persp(rotate(on_page(base),3),0.0012),t)
    save(f'p{pi}_persp2',persp(rotate(on_page(base),-4),-0.0018),t)
    save(f'p{pi}_shadow',noise(shadow(rotate(on_page(base),2),0.5),5),t)
    save(f'p{pi}_blob',noise(blobshadow(rotate(on_page(base),-2),0.6),5),t)
    save(f'p{pi}_glare',noise(glare(rotate(on_page(base),3),0.6),4),t)
    save(f'p{pi}_curve',noise(curve(on_page(base),14),4),t)
    low=grid(t,fp,cell=34)
    save(f'p{pi}_lowres',noise(rotate(on_page(low),2),5),t)
    save(f'p{pi}_jpeg',noise(rotate(on_page(base),-3),8),t,q=18)
    save(f'p{pi}_faint',noise(rotate(on_page(grid(t,fp,ink=130)),2).filter(ImageFilter.GaussianBlur(1.3)),4),t)
    save(f'p{pi}_combo',noise(blobshadow(shadow(persp(rotate(on_page(base),5),0.0009),0.35),0.35),6).filter(ImageFilter.GaussianBlur(0.8)),t,q=40)
json.dump(cases,open(f'{OUT}/truth.json','w'))
print(len(cases))
