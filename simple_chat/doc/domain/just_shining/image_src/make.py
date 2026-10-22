"""Draws one product illustration per Just Shining model as SVG.

Writes <model>.svg next to this script:

  python3 make.py

To also render <model>.png into a folder, for publishing to
https://github.com/polina-c/a2ui-spikes-binaries (see
.agent/skills/coding/SKILL.md), pass the folder:

  python3 make.py /path/to/png_folder

Rendering uses headless Google Chrome.
"""
import pathlib, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
W, H = 560, 640
CM = 5            # pixels per centimeter
FLOOR = 560       # top of the floor
BUILTIN_H = 82 * CM

DEFS = """
<defs>
  <linearGradient id="steel" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#C3C9D1"/><stop offset=".45" stop-color="#E9ECF0"/>
    <stop offset="1" stop-color="#B4BBC4"/>
  </linearGradient>
  <linearGradient id="darksteel" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#3A414C"/><stop offset=".5" stop-color="#555E6B"/>
    <stop offset="1" stop-color="#363C46"/>
  </linearGradient>
  <linearGradient id="wall" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#F4F6F8"/><stop offset="1" stop-color="#E6EAEE"/>
  </linearGradient>
  <radialGradient id="glow" cx=".5" cy=".5" r=".5">
    <stop offset="0" stop-color="#7FD3FF" stop-opacity=".95"/>
    <stop offset="1" stop-color="#7FD3FF" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="glass" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#9FB3C6" stop-opacity=".9"/>
    <stop offset="1" stop-color="#5E7388" stop-opacity=".9"/>
  </linearGradient>
</defs>"""


def room(night=False):
  wall = '#2B3140' if night else 'url(#wall)'
  floor = '#3A4150' if night else '#CDD2D8'
  return (f'<rect width="{W}" height="{H}" fill="{wall}"/>'
          f'<rect y="{FLOOR}" width="{W}" height="{H-FLOOR}" fill="{floor}"/>'
          f'<rect y="{FLOOR}" width="{W}" height="3" fill="#000" opacity=".08"/>')


def cabinets(gap_x, gap_w, night=False):
  """Base cabinets on both sides of a gap, with the countertop over all."""
  top = FLOOR - BUILTIN_H
  door = '#4A5263' if night else '#FBFBFA'
  edge = '#2F3542' if night else '#D5D9DE'
  s = ''
  for x0, x1 in ((0, gap_x - 2), (gap_x + gap_w + 2, W)):
    s += f'<rect x="{x0}" y="{top}" width="{x1-x0}" height="{BUILTIN_H}" fill="{door}" stroke="{edge}" stroke-width="2"/>'
    # Doors and handles.
    n = max(1, round((x1 - x0) / 150))
    dw = (x1 - x0) / n
    for i in range(n):
      dx = x0 + i * dw
      s += f'<rect x="{dx+6}" y="{top+10}" width="{dw-12}" height="{BUILTIN_H-40}" rx="3" fill="none" stroke="{edge}" stroke-width="2"/>'
      s += f'<rect x="{dx+dw/2-22}" y="{top+30}" width="44" height="6" rx="3" fill="#9AA2AD"/>'
    s += f'<rect x="{x0}" y="{FLOOR-28}" width="{x1-x0}" height="28" fill="{edge}"/>'
  s += f'<rect x="0" y="{top-26}" width="{W}" height="26" fill="#5B6472"/>'
  s += f'<rect x="0" y="{top-26}" width="{W}" height="4" fill="#fff" opacity=".18"/>'
  return s


def machine(x, w, h, name, dark=False, display='0:59', display_color='#6FE3FF'):
  """Front view of a dishwasher whose bottom edge sits on the floor line."""
  y = FLOOR - h
  body = 'url(#darksteel)' if dark else 'url(#steel)'
  panel = '#1E232B'
  s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{body}" stroke="#8A929C" stroke-width="2"/>'
  s += f'<rect x="{x}" y="{y}" width="{w}" height="54" rx="6" fill="{panel}"/>'
  s += f'<rect x="{x}" y="{y+44}" width="{w}" height="10" fill="{panel}"/>'
  s += f'<text x="{x+16}" y="{y+33}" font-family="Helvetica, Arial" font-size="15" fill="#D8DEE6" letter-spacing="1">{name.upper()}</text>'
  s += f'<rect x="{x+w-96}" y="{y+15}" width="62" height="24" rx="4" fill="#0B0E12"/>'
  s += f'<text x="{x+w-65}" y="{y+33}" text-anchor="middle" font-family="Menlo, monospace" font-size="15" fill="{display_color}">{display}</text>'
  s += f'<circle cx="{x+w-18}" cy="{y+27}" r="7" fill="none" stroke="#9AA4B0" stroke-width="2"/>'
  # Handle.
  s += f'<rect x="{x+w*0.2}" y="{y+72}" width="{w*0.6}" height="12" rx="6" fill="#8D96A1" stroke="#6E7782" stroke-width="1.5"/>'
  # Sheen on the door.
  s += f'<rect x="{x+w*0.12}" y="{y+100}" width="{w*0.07}" height="{h-130}" rx="4" fill="#fff" opacity="{0.08 if dark else 0.35}"/>'
  s += f'<rect x="{x+6}" y="{FLOOR-22}" width="{w-12}" height="16" rx="3" fill="#000" opacity=".25"/>'
  return s


def dimension(x, w, label, color='#5B6472'):
  y = FLOOR + 40
  return (f'<line x1="{x}" y1="{y}" x2="{x+w}" y2="{y}" stroke="{color}" stroke-width="2"/>'
          f'<line x1="{x}" y1="{y-10}" x2="{x}" y2="{y+10}" stroke="{color}" stroke-width="2"/>'
          f'<line x1="{x+w}" y1="{y-10}" x2="{x+w}" y2="{y+10}" stroke="{color}" stroke-width="2"/>'
          f'<rect x="{x+w/2-38}" y="{y-14}" width="76" height="28" rx="14" fill="#fff" stroke="{color}" stroke-width="2"/>'
          f'<text x="{x+w/2}" y="{y+6}" text-anchor="middle" font-family="Helvetica, Arial" font-weight="bold" font-size="16" fill="{color}">{label}</text>')


def badge(cx, cy, inner, fill='#fff', stroke='#5B6472'):
  # Icons are drawn around (700, 62); this moves them to the top right corner.
  return (f'<g transform="translate({W - 62 - cx} 0)">'
          f'<circle cx="{cx}" cy="{cy}" r="42" fill="{fill}" stroke="{stroke}" stroke-width="3"/>' + inner + '</g>')


def svg(body):
  return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{DEFS}{body}</svg>'


def builtin(width_cm, name, **kw):
  w = width_cm * CM
  x = (W - w) / 2
  return x, w, cabinets(x, w, kw.pop('night', False)) + machine(x, w, BUILTIN_H, name, **kw)


images = {}

# Mini: a countertop machine on a table next to a faucet, with an inlet hose.
counter_y = 400
mini_w, mini_h = 55 * CM, 44 * CM
mx = 300
# machine() draws from the floor, so it is shifted up onto the counter.
images['mini'] = (room()
  + f'<rect x="0" y="{counter_y}" width="{W}" height="24" fill="#5B6472"/>'
  + f'<rect x="0" y="{counter_y+24}" width="{W}" height="{FLOOR-counter_y-24}" fill="#FBFBFA" stroke="#D5D9DE" stroke-width="2"/>'
  + f'<rect x="20" y="{counter_y+40}" width="{W-40}" height="{FLOOR-counter_y-70}" rx="3" fill="none" stroke="#D5D9DE" stroke-width="2"/>'
  + '<g transform="translate(-40 0)">'
  + f'<rect x="60" y="{counter_y-6}" width="180" height="10" rx="4" fill="#AEB5BE"/>'
  + f'<path d="M150 {counter_y-6} v-90 q0 -30 30 -30 h40 q14 0 14 14 v14" fill="none" stroke="#9AA2AD" stroke-width="12" stroke-linecap="round"/>'
  + f'<rect x="132" y="{counter_y-28}" width="36" height="22" rx="4" fill="#9AA2AD"/>'
  + f'<path d="M234 {counter_y-112} c40 0 40 60 75 60" fill="none" stroke="#4E5A68" stroke-width="7" stroke-linecap="round"/>'
  + f'<g transform="translate(0 {counter_y-FLOOR})">' + machine(mx, mini_w, mini_h, 'Mini', display='0:40') + '</g>' + '</g>'
  + badge(700, 62, '<path d="M700 34 c-14 20 -22 32 -22 44 a22 22 0 0 0 44 0 c0 -12 -8 -24 -22 -44z" fill="#5AA9E6"/>'
          '<text x="700" y="86" text-anchor="middle" font-family="Helvetica, Arial" font-weight="bold" font-size="15" fill="#fff">5 L</text>'))

# Slim: a narrow 45 cm machine.
x, w, body = builtin(45, 'Slim', display='1:10')
images['slim'] = room() + body + dimension(x, w, '45 cm')

# Classic: the standard 60 cm machine with its quick 60 program on the display.
x, w, body = builtin(60, 'Classic', display='1:00')
images['classic'] = (room() + body + dimension(x, w, '60 cm')
  + badge(700, 62, '<circle cx="700" cy="62" r="24" fill="none" stroke="#5B6472" stroke-width="4"/>'
          '<path d="M700 46 v16 h12" fill="none" stroke="#5B6472" stroke-width="4" stroke-linecap="round"/>'))

# Family: 60 cm with three racks, shown by a stack of plates.
x, w, body = builtin(60, 'Family', display='2:10')
plates = ''.join(f'<rect x="672" y="{40+i*16}" width="56" height="10" rx="5" fill="#5B6472"/>' for i in range(3))
images['family'] = (room() + body + dimension(x, w, '60 cm')
  + badge(700, 62, plates))

# Silent: a dark kitchen at night, with the status light on the floor.
x, w, body = builtin(60, 'Silent', night=True, dark=True, display='39dB', display_color='#9BE7FF')
images['silent'] = (room(night=True)
  + f'<ellipse cx="{x+w/2}" cy="{FLOOR+38}" rx="110" ry="22" fill="url(#glow)"/>'
  + body
  + badge(700, 62, '<path d="M712 36 a28 28 0 1 0 14 44 a22 22 0 1 1 -14 -44z" fill="#F5E6A8"/>', fill='#3A4150', stroke='#6C7689'))

# Eco: 60 cm with a leaf and a drop for the low consumption.
x, w, body = builtin(60, 'Eco', display='6.8L', display_color='#8EF0A6')
images['eco'] = (room() + body + dimension(x, w, '60 cm', color='#2F8F57')
  + badge(700, 62, '<path d="M680 84 c0 -36 24 -52 46 -52 c2 26 -10 52 -42 52z" fill="#3DAA63"/>'
          '<path d="M684 82 q14 -22 34 -40" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>',
          stroke='#2F8F57'))

png_dir = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
for name, body in images.items():
  path = HERE / f'{name}.svg'
  path.write_text(svg(body))
  if png_dir:
    png_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
      [CHROME, '--headless', '--disable-gpu', '--hide-scrollbars',
       '--force-device-scale-factor=1', f'--window-size={W},{H}',
       f'--screenshot={png_dir / f"{name}.png"}', path.as_uri()],
      check=True, capture_output=True)
  print(path.name)
