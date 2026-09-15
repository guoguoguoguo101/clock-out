package sim

import "math"

type Vec struct {
	X, Y float64
}

func (v Vec) Add(o Vec) Vec      { return Vec{v.X + o.X, v.Y + o.Y} }
func (v Vec) Sub(o Vec) Vec      { return Vec{v.X - o.X, v.Y - o.Y} }
func (v Vec) Mul(s float64) Vec  { return Vec{v.X * s, v.Y * s} }
func (v Vec) Len() float64       { return math.Hypot(v.X, v.Y) }
func (v Vec) Dist(o Vec) float64 { return v.Sub(o).Len() }
func (v Vec) Dot(o Vec) float64  { return v.X*o.X + v.Y*o.Y }

func DistPointSeg(p, a, b Vec) float64 {
	ab := b.Sub(a)
	den := ab.X*ab.X + ab.Y*ab.Y
	t := 0.0
	if den >= 0.001 {
		t = p.Sub(a).Dot(ab) / den
		if t < 0 {
			t = 0
		}
		if t > 1 {
			t = 1
		}
	}
	return p.Dist(a.Add(ab.Mul(t)))
}

func (v Vec) Normalized() Vec {
	l := v.Len()
	if l < 1e-6 {
		return Vec{}
	}
	return Vec{v.X / l, v.Y / l}
}

func (v Vec) Limit(max float64) Vec {
	l := v.Len()
	if l <= max || l < 1e-6 {
		return v
	}
	return v.Mul(max / l)
}

type Rect struct {
	X, Y, W, H float64
}

func (r Rect) Contains(p Vec) bool {
	return p.X >= r.X && p.X <= r.X+r.W && p.Y >= r.Y && p.Y <= r.Y+r.H
}

func (r Rect) Center() Vec { return Vec{r.X + r.W*0.5, r.Y + r.H*0.5} }

func RectFromCenter(c Vec, w, h float64) Rect {
	return Rect{X: c.X - w*0.5, Y: c.Y - h*0.5, W: w, H: h}
}

func Clamp(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func CircleHitsRect(c Vec, radius float64, r Rect) bool {
	cx := Clamp(c.X, r.X, r.X+r.W)
	cy := Clamp(c.Y, r.Y, r.Y+r.H)
	dx := c.X - cx
	dy := c.Y - cy
	return dx*dx+dy*dy < radius*radius
}

func SegmentHitsRect(a, b Vec, r Rect) bool {
	if r.Contains(a) || r.Contains(b) {
		return true
	}
	// Slab / Liang-Barsky
	dx := b.X - a.X
	dy := b.Y - a.Y
	t0, t1 := 0.0, 1.0
	if !slab(dx, a.X, r.X, r.X+r.W, &t0, &t1) {
		return false
	}
	if !slab(dy, a.Y, r.Y, r.Y+r.H, &t0, &t1) {
		return false
	}
	return true
}

func slab(d, p, min, max float64, t0, t1 *float64) bool {
	if math.Abs(d) < 1e-9 {
		return p >= min && p <= max
	}
	inv := 1.0 / d
	tA := (min - p) * inv
	tB := (max - p) * inv
	if tA > tB {
		tA, tB = tB, tA
	}
	if tA > *t0 {
		*t0 = tA
	}
	if tB < *t1 {
		*t1 = tB
	}
	return *t0 <= *t1
}

func PushCircleOut(c Vec, radius float64, r Rect) Vec {
	if !CircleHitsRect(c, radius, r) {
		return c
	}
	cx := Clamp(c.X, r.X, r.X+r.W)
	cy := Clamp(c.Y, r.Y, r.Y+r.H)
	dx := c.X - cx
	dy := c.Y - cy
	d := math.Hypot(dx, dy)
	if d < 1e-6 {
		// Center inside rect: push along smallest overlap.
		left := c.X - r.X
		right := r.X + r.W - c.X
		top := c.Y - r.Y
		bot := r.Y + r.H - c.Y
		m := left
		out := Vec{c.X - (left + radius), c.Y}
		if right < m {
			m = right
			out = Vec{c.X + (right + radius), c.Y}
		}
		if top < m {
			m = top
			out = Vec{c.X, c.Y - (top + radius)}
		}
		if bot < m {
			out = Vec{c.X, c.Y + (bot + radius)}
		}
		return out
	}
	need := radius - d
	return c.Add(Vec{dx / d, dy / d}.Mul(need + 0.01))
}
