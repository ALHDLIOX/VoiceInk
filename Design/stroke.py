"""Generates AppIcon.svg and MenuBarIcon.svg: one hand-written brush-pen stroke.

stroke-cols.txt was measured column by column from a reference stroke (x, ink centre y, vertical ink thickness).
A polynomial is fitted to the centreline and to the true width; the stroke is then scaled up, its wave made
taller (AMP), and drawn as a filled outline with a round head and a pointed tail.

    python3 Design/stroke.py      # rewrites Design/AppIcon.svg and Design/MenuBarIcon.svg
"""
import math, os
HERE = os.path.dirname(os.path.abspath(__file__))
rows = [tuple(map(float, l.split())) for l in open(os.path.join(HERE, 'stroke-cols.txt'))]
def lsq(xs, ys, deg):
    m = deg + 1
    A = [[sum(x**(i+j) for x in xs) for j in range(m)] + [sum(y*x**i for x, y in zip(xs, ys))] for i in range(m)]
    for c in range(m):
        p = max(range(c, m), key=lambda r: abs(A[r][c])); A[c], A[p] = A[p], A[c]
        for r in range(m):
            if r != c:
                f = A[r][c]/A[c][c]; A[r] = [a - f*b for a, b in zip(A[r], A[c])]
    co = [A[i][m]/A[i][i] for i in range(m)]
    return lambda x: sum(c*x**i for i, c in enumerate(co))
X0, X1 = 34.0, 296.0
nx = lambda x: (x - (X0+X1)/2)/((X1-X0)/2)
cen = [r for r in rows if 36 <= r[0] <= 292]
fy = lsq([nx(r[0]) for r in cen], [r[1] for r in cen], 6)
def slope(x, h=0.5): return (fy(nx(x+h)) - fy(nx(x-h)))/(2*h)
wid = [r for r in rows if 38 <= r[0] <= 280]
fw = lsq([nx(r[0]) for r in wid], [r[2]*math.cos(math.atan(slope(r[0]))) for r in wid], 4)

def build(width, wk=1.0, ak=1.0, cx=512, cy=512, N=500):
    xs = [X0 + (X1-X0)*i/N for i in range(N+1)]
    k = width/(X1-X0)
    ym = (max(fy(nx(x)) for x in xs) + min(fy(nx(x)) for x in xs))/2
    P = [((x-(X0+X1)/2)*k, (fy(nx(x))-ym)*k*ak) for x in xs]
    L, R = [], []
    for i, x in enumerate(xs):
        a, b = P[max(0, i-1)], P[min(N, i+1)]
        tx, ty = b[0]-a[0], b[1]-a[1]; d = math.hypot(tx, ty); tx, ty = tx/d, ty/d
        u = i/N
        taper = 1 - max(0.0, (u - 0.80)/0.20)**1.7          # 最后两成提笔出尖
        w = fw(nx(min(x, 280)))*k*wk*taper
        L.append((P[i][0]-ty*w/2, P[i][1]+tx*w/2)); R.append((P[i][0]+ty*w/2, P[i][1]-tx*w/2))
    # 起笔圆头
    a = P[0]; b = P[1]; tx, ty = b[0]-a[0], b[1]-a[1]; d = math.hypot(tx, ty); tx, ty = tx/d, ty/d
    r0 = math.dist(L[0], R[0])/2; aR = math.atan2(R[0][1]-a[1], R[0][0]-a[0]); best = None
    for sgn in (1, -1):
        arc = [(a[0]+r0*math.cos(aR+sgn*math.pi*j/24), a[1]+r0*math.sin(aR+sgn*math.pi*j/24)) for j in range(1, 24)]
        back = (arc[11][0]-a[0])*(-tx) + (arc[11][1]-a[1])*(-ty)
        if best is None or back > best[0]: best = (back, arc)
    pts = L + [P[-1]] + R[::-1] + best[1]
    xsP = [p[0] for p in pts]; ysP = [p[1] for p in pts]
    dx = cx - (max(xsP)+min(xsP))/2; dy = cy - (max(ysP)+min(ysP))/2
    return 'M' + 'L'.join(f'{x+dx:.1f} {y+dy:.1f}' for x, y in pts) + 'Z'

AMP = 1.8  # wave height relative to the reference stroke

app = build(680, ak=AMP)
open(os.path.join(HERE, 'AppIcon.svg'), 'w').write(f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#000000"/>
  <path d="{app}" fill="#FFFFFF"/>
</svg>
''')
# menu bar: template image, only alpha matters; a bit heavier so it holds up at 22pt
mb = build(700, wk=1.3, ak=AMP, cx=375, cy=375)
open(os.path.join(HERE, 'MenuBarIcon.svg'), 'w').write(f'''<svg xmlns="http://www.w3.org/2000/svg" width="750" height="750" viewBox="0 0 750 750">
  <path d="{mb}" fill="#000000"/>
</svg>
''')
