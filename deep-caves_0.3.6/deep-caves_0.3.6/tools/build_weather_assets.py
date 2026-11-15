from pathlib import Path
import random, wave
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
r=Path(__file__).resolve().parents[1]
rng=random.Random(934192)
for name,count,width,opacity in [('rain-far',110,1,38),('rain-near',72,1,90)]:
 drops=[(rng.uniform(0,256),rng.uniform(0,256),rng.uniform(12,30),rng.uniform(.55,1)) for _ in range(count)]
 sheet=Image.new('RGBA',(2048,1024))
 for f in range(32):
  tile=Image.new('RGBA',(256,256));d=ImageDraw.Draw(tile)
  for x,y,length,gain in drops:
   x=(x+f*8)%256;y=(y+f*16)%256
   for ox in [-256,0,256]:
    for oy in [-256,0,256]:
     for step in range(6):
      lo=step/6;hi=(step+1)/6
      d.line([(x+ox-length*.35*(1-lo),y+oy-length*(1-lo)),(x+ox-length*.35*(1-hi),y+oy-length*(1-hi))],fill=(185,211,230,int(opacity*gain*(.1+.9*hi))),width=width)
  sheet.paste(tile,(f%8*256,f//8*256))
 sheet.save(r/f'graphics/weather/{name}.png')
Image.new('RGBA',(1,1),(255,255,255,255)).save(r/'graphics/weather/screen.png')
# All audio is synthesized locally; no external recordings or licenses needed.
sr=24000;rand=np.random.default_rng(81928)
def write(name,samples):
 samples=np.clip(samples,-.98,.98)
 with wave.open(str(r/f'sound/weather/{name}.wav'),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes((samples*32767).astype('<i2').tobytes())
t=np.arange(sr*2)/sr
# Two seconds of rain, with a half-second equal-power crossfade at each end.
# Play a fresh clip every 1.5 seconds: sin^2 + cos^2 = 1 in the overlap.
fade=.5
attack=np.sin(np.minimum(1,t/fade)*np.pi/2)
release=np.sin(np.minimum(1,(2-t)/fade)*np.pi/2)
env=attack*release
for k in range(1,5):
 white=rand.normal(0,1,len(t));smooth=np.convolve(white,np.ones(9)/9,mode='same')
 rain=.08*white+.16*smooth
 for i in range(180):
  at=rand.integers(0,len(t)-400);n=rand.integers(30,260)
  rain[at:at+n]+=.05*rand.normal(0,1,n)*np.exp(-np.arange(n)/(n*.3))
 write(f'rain-{k}',rain*env)
for k in [1,2]:
 t=np.arange(sr*5)/sr;noise=rand.normal(0,1,len(t))
 spectrum=np.fft.rfft(noise);freq=np.fft.rfftfreq(len(t),1/sr)
 filt=1/np.sqrt(1+(freq/110)**4)
 bass=np.fft.irfft(spectrum*filt,n=len(t));bass/=max(abs(bass))
 swell=(1-np.exp(-t*16))*np.exp(-t*.65)
 rumble=.58*bass*swell*(.7+.3*np.sin(t*3.7+k)**2)
 crack=.08*noise*np.exp(-t*17)
 write(f'thunder-{k}',rumble+crack)
print('Created looping rain animation sheets and rain/thunder WAV files')
