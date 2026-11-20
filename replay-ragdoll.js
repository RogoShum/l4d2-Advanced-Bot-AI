'use strict';
// Visual reconstruction from the final recorded pose. Fixed steps make seeking deterministic.
globalThis.ReplayRagdolls = class {
	constructor(map) {
		this.cells = new Map(); this.bodies = new Map(); this.deadline = Infinity;
		this.world = map.collision;
	}
	// World triangles bucketed on a 256-unit XY grid, built once in budgeted slices.
	// Several corpses' step generators can be suspended in here at once and share one build.
	// Each slice is indexed without yielding and the shared cursor is advanced before the
	// next yield, so a resumed generator never continues from another one's stale group
	// (that pushed triangle codes past the last group: "reading 'vertices'" in cell()).
	*grid() {
		// 64-unit buckets keep each lookup short (256 held thousands of prop triangles); triangles
		// spanning more than 400 buckets go to one list that every lookup also checks.
		const size = 64;
		while (!this.index) {
			const cells = this.building || (this.building = {cells:new Map(), large:[], group:0, at:0});
			if (cells.group >= this.world.length) { this.index = {size, cells:cells.cells, large:cells.large}; this.building = null; break; }
			const group = cells.group, v = this.world[group].vertices, end = Math.min(v.length, cells.at + 18000);
			for (let i = cells.at; i < end; i += 9) {
				const x0 = Math.floor(Math.min(v[i], v[i + 3], v[i + 6]) / size), x1 = Math.floor(Math.max(v[i], v[i + 3], v[i + 6]) / size), y0 = Math.floor(Math.min(v[i + 1], v[i + 4], v[i + 7]) / size), y1 = Math.floor(Math.max(v[i + 1], v[i + 4], v[i + 7]) / size);
				if ((x1 - x0 + 1) * (y1 - y0 + 1) > 400) { cells.large.push(group * 16777216 + i / 9); continue; }
				for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++) { const key = x * 65536 + y; let list = cells.cells.get(key); if (!list) cells.cells.set(key, list = []); list.push(group * 16777216 + i / 9); }
			}
			if (end >= v.length) { cells.group = group + 1; cells.at = 0; } else cells.at = end;
			if (performance.now() >= this.deadline) yield;
		}
		return this.index;
	}
	// Triangles near a 16-unit cell (plus a radius margin). Triangle records are shared between
	// cells and each list carries packed bounds, so the per-sphere test rejects most of a busy
	// cell (static-prop detail, displacements) without touching the records.
	*cell(point, radius) {
		const cell = point.map(v => Math.floor(v/16)), margin = Math.ceil(radius/8)*8, key = cell.join(',')+':'+margin; if (this.cells.has(key)) return this.cells.get(key);
		const lo = cell.map(v => v*16-margin), hi = cell.map(v => v*16+16+margin), result = [], grid = yield* this.grid(), seen = new Set(), records = this.records || (this.records = new Map());
		for (let x = Math.floor(lo[0] / grid.size); x <= Math.floor(hi[0] / grid.size); x++) for (let y = Math.floor(lo[1] / grid.size); y <= Math.floor(hi[1] / grid.size + (x === Math.floor(hi[0] / grid.size) ? 1 : 0)); y++) for (const code of y > Math.floor(hi[1] / grid.size) ? grid.large : grid.cells.get(x * 65536 + y) || []) {
			if (seen.has(code)) continue; seen.add(code);
			let tri = records.get(code);
			if (tri === undefined) {
				const v = this.world[Math.floor(code / 16777216)].vertices, i = (code % 16777216) * 9;
				const a = Array.from(v.subarray(i,i+3)), b = Array.from(v.subarray(i+3,i+6)), c = Array.from(v.subarray(i+6,i+9));
				const ab = b.map((x,k) => x-a[k]), ac = c.map((x,k) => x-a[k]), normal = [ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]], length = Math.hypot(...normal);
				tri = length < .01 ? null : {a,b,c,n:normal.map(x => x/length),bounds:[Math.min(a[0],b[0],c[0]),Math.min(a[1],b[1],c[1]),Math.min(a[2],b[2],c[2]),Math.max(a[0],b[0],c[0]),Math.max(a[1],b[1],c[1]),Math.max(a[2],b[2],c[2])]};
				records.set(code, tri);
			}
			if (!tri) continue; const t = tri.bounds;
			if (t[0] > hi[0] || t[3] < lo[0] || t[1] > hi[1] || t[4] < lo[1] || t[2] > hi[2] || t[5] < lo[2]) continue;
			result.push(tri);
		}
		result.box = new Float32Array(result.length*6); result.forEach((tri, k) => result.box.set(tri.bounds, k*6));
		this.cells.set(key,result); if(this.cells.size>8192)this.cells.delete(this.cells.keys().next().value); return result;
	}
	cached(point, radius) { const key = Math.floor(point[0]/16)+','+Math.floor(point[1]/16)+','+Math.floor(point[2]/16)+':'+Math.ceil(radius/8)*8; return this.cells.get(key); }
	*collide(p, previous, radius) {
		const triangles = this.cached(p, radius) || (yield* this.cell(p,radius));
		return ReplayRagdolls.push(p, previous, radius, triangles);
	}
	static push(p, previous, radius, triangles) {
		let contact = false;
		const low = Math.min(p[2],previous[2])-radius, high = Math.max(p[2],previous[2])+radius, box = triangles.box;
		for (let index = 0, o = 0; index < triangles.length; index++, o += 6) {
			if (low > box[o+5] || high < box[o+2] || p[0] - radius > box[o+3] || p[0] + radius < box[o] || p[1] - radius > box[o+4] || p[1] + radius < box[o+1]) continue;
			const tri = triangles[index];
			const n = tri.n, a0 = tri.a, distance = (p[0]-a0[0])*n[0]+(p[1]-a0[1])*n[1]+(p[2]-a0[2])*n[2], oldDistance = (previous[0]-a0[0])*n[0]+(previous[1]-a0[1])*n[1]+(previous[2]-a0[2])*n[2];
			if (distance >= radius || oldDistance < 0) continue;
			const qx = p[0]-n[0]*distance, qy = p[1]-n[1]*distance, qz = p[2]-n[2]*distance; let inside = true;
			for (let edge = 0; edge < 3; edge++) { const a = edge === 0 ? tri.a : edge === 1 ? tri.b : tri.c, b = edge === 0 ? tri.b : edge === 1 ? tri.c : tri.a, ux = b[0]-a[0], uy = b[1]-a[1], uz = b[2]-a[2], vx = qx-a[0], vy = qy-a[1], vz = qz-a[2]; if ((uy*vz-uz*vy)*n[0]+(uz*vx-ux*vz)*n[1]+(ux*vy-uy*vx)*n[2] < -.01) { inside = false; break; } }
			if (!inside) continue;
			p[0] += n[0]*(radius-distance); p[1] += n[1]*(radius-distance); p[2] += n[2]*(radius-distance);
			contact = true;
		}
		return contact;
	}
	create(key, model, world, velocities, impacts = []) {
		const boneIds = new Map(model.bones.map(bone => [bone.name,bone.id])), physics = new Map(), hitboxes = (model.hitboxSets || []).flatMap(set => set.boxes);
		for (const solid of model.physics || []) { const id = boneIds.get(solid.name); if (id !== undefined) physics.set(id,{...solid,hulls:model.collision?.solids[solid.index] || []}); }
		const driven = new Set(physics.size ? physics.keys() : hitboxes.length ? hitboxes.map(box => box.bone) : model.used), selectedIds = new Set(driven);
		// Preserve the actual joint chains between physics bodies, including unweighted helper bones.
		for (const id of driven) { const chain = []; let parent = model.bones[id].parent; while (parent >= 0 && !driven.has(parent)) { chain.push(parent); parent = model.bones[parent].parent; } if (parent >= 0) for (const bone of chain) selectedIds.add(bone); }
		const selected = [...selectedIds].sort((a,b) => a-b); if (!selected.length) { this.bodies.set(key,null); return null; }
		const labels = model.bones.map(bone => bone.name.replace(/^ValveBiped\.(?:Bip01_)?/i,'').replace(/^bip_(upperArm|lowerArm|hand|hip|knee|foot)_([LR])$/i,(_,part,side) => side+'_'+({lowerarm:'Forearm',hip:'Thigh',knee:'Calf'}[part.toLowerCase()] || part)).replace(/^bip_/i,'').replace(/^(spine|neck)_(\d+)$/i,'$1$2').toLowerCase());
		const names = selected.map(id => labels[id]), index = new Map(selected.map((id,i) => [id,i])), rest = selected.map(id => Array.from(world[id].slice(12,15))), nodes = rest.map((p,i) => ({p:p.slice(),prev:p.map((v,k) => v-velocities[selected[i]][k]/60),mass:physics.get(selected[i])?.mass || 0,radius:0})), links = [], limits = [], parent = [], segments = [];
		for (let i = 0; i < selected.length; i++) { let p = model.bones[selected[i]].parent; while (p >= 0 && !index.has(p)) p = model.bones[p].parent; parent[i] = index.get(p) ?? -1; if (parent[i] >= 0) links.push([i,parent[i],Math.hypot(...rest[i].map((v,k) => v-rest[parent[i]][k]))]); }
		for (let i = 0; i < selected.length; i++) {
			const id = selected[i], hulls = physics.get(id)?.hulls, lo = [Infinity,Infinity,Infinity], hi = [-Infinity,-Infinity,-Infinity];
			if (hulls?.length) for (const hull of hulls) for (let vertex = 0; vertex < hull.vertices.length; vertex += 3) for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k],hull.vertices[vertex+k]); hi[k] = Math.max(hi[k],hull.vertices[vertex+k]); }
			else for (const box of hitboxes) if (box.bone === id) for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k],box.mins[k]); hi[k] = Math.max(hi[k],box.maxs[k]); }
			// Half the smallest hull extent, slightly padded: thin limbs otherwise sink into each other and the floor.
			if (lo[0] !== Infinity) nodes[i].radius = Math.max(0,Math.min(...hi.map((v,k) => v-lo[k]))/2)*1.15;
		}
		for (let i = 0; i < nodes.length; i++) if (!nodes[i].radius) {
			let source = parent[i]; while (source >= 0 && !nodes[source].radius) source = parent[source];
			const lengths = links.filter(([a,b,length]) => (a === i || b === i) && length > 0).map(link => link[2]); nodes[i].radius = source >= 0 ? nodes[source].radius : lengths.length ? Math.min(...lengths)/4 : 0;
		}
		for (const [i,j] of links) { const radius = Math.min(nodes[i].radius,nodes[j].radius); if (radius > 0) segments.push([i,j,radius]); }
		for (let i = 0; i < selected.length; i++) if (/(?:Hand|Foot)$/i.test(names[i])) { const p = parent[i], root = parent[p]; if (root >= 0) limits.push([i,root,(Math.hypot(...rest[i].map((v,k) => v-rest[p][k]))+Math.hypot(...rest[p].map((v,k) => v-rest[root][k])))*(/Foot$/i.test(names[i])?.55:.35)]); }
		const named = name => names.indexOf(name.toLowerCase()), pelvis = named('Pelvis'), chest = names.findLastIndex(name => /^spine/.test(name)), left = named('L_UpperArm'), right = named('R_UpperArm');
		// Knees are hinges: remember on which side of the hip-foot line each knee sits relative to the
		// body's facing in the death pose, and keep it there (no backwards-bending legs).
		const hinges = [];
		if (pelvis >= 0 && chest >= 0 && left >= 0 && right >= 0) for (const side of ['L', 'R']) { const knee = named(side + '_Calf'), hip = named(side + '_Thigh'), foot = named(side + '_Foot'); if (knee >= 0 && hip >= 0 && foot >= 0) hinges.push({hip, knee, foot, side:Math.sign(ReplayRagdolls.bendSide(rest, hip, knee, foot, pelvis, chest, left, right)) || 1}); }
		const torso = names.map((name,i) => /pelvis|spine|upperarm|thigh/i.test(name)?i:-1).filter(i => i >= 0);
		for (let a = 0; a < torso.length; a++) for (let b = a+1; b < torso.length; b++) { const i = torso[a],j = torso[b]; links.push([i,j,Math.hypot(...rest[i].map((v,k) => v-rest[j][k]))]); }
		const anchor = model.bones.map(bone => { let id = bone.id; while (id >= 0 && !index.has(id)) id = model.bones[id].parent; return index.get(id) ?? 0; });
		const mass = nodes.reduce((sum,node) => sum+node.mass,0);
		// Endpoint nodes share their parent's mass; preserve the source model's total mass.
		for (let i = 0; i < nodes.length; i++) if (!nodes[i].mass) { const source = parent[i] >= 0 ? nodes[parent[i]] : nodes[0], share = source.mass*.1; nodes[i].mass = share; source.mass -= share; }
		for (const node of nodes) node.inverseMass = node.mass > 0 ? 1/node.mass : 1;
		for (const impact of impacts) {
			if (!mass) break;
			let nearest = nodes.findIndex(node => node.mass > 0); for (let i = 0; i < nodes.length; i++) if (nodes[i].mass > 0 && Math.hypot(...rest[i].map((v,k) => v-impact.position[k])) < Math.hypot(...rest[nearest].map((v,k) => v-impact.position[k]))) nearest = i;
			if (impact.velocity) {
				// Killing blow as a velocity (in/s): the whole body is carried along the shot, the hit part
				// and its neighbours harder, as a bone hit by ApplyForceOffset drags the rest through the joints.
				for (let i = 0; i < nodes.length; i++) { const hit = i === nearest ? 1.8 : parent[i] === nearest || parent[nearest] === i ? 1.35 : 1; for (let k = 0; k < 3; k++) nodes[i].prev[k] -= impact.velocity[k]*hit/60; }
				continue;
			}
			for (let i = 0; i < nodes.length; i++) for (let k = 0; k < 3; k++) nodes[i].prev[k] -= impact.force[k]/(i === nearest ? nodes[i].mass : mass)/60;
		}
		const body = {model,world,selected,names,index,rest,nodes,links,limits,segments,parent,anchor,hinges,torso:[pelvis,chest,left,right],frames:[new Float32Array(rest.flat())],frameStart:0,frameCount:0,settled:false}; this.bodies.set(key,body); return body;
	}
	// Keep a partially evaluated constraint step across display frames when its budget expires.
	*step(body) {
		if (body.settled) return;
		const nodes = body.nodes, rest = body.rest, parent = body.parent, point = [0, 0, 0], old = [0, 0, 0];
		for (const node of nodes) { const o = node.prev; node.contact = false; for (let k = 0; k < 3; k++) { const p = node.p[k]; node.p[k] += (p-o[k])*.986-(k===2?800/3600:0); o[k] = p; } }
		const constrain = (list, limit) => { for (const [i,j,length] of list) { const a = nodes[i].p, b = nodes[j].p, dx = b[0]-a[0], dy = b[1]-a[1], dz = b[2]-a[2], d = Math.sqrt(dx*dx+dy*dy+dz*dz); if (d < .00001 || limit && d >= length) continue; const correction = (d-length)/d, ma = nodes[i].mass, mb = nodes[j].mass, weight = ma+mb > 0 ? mb/(ma+mb) : .5, wa = correction*weight, wb = correction*(1-weight); a[0] += dx*wa; a[1] += dy*wa; a[2] += dz*wa; b[0] -= dx*wb; b[1] -= dy*wb; b[2] -= dz*wb; } };
		for (let pass = 0; pass < 8; pass++) {
			if (performance.now() >= this.deadline) yield;
			constrain(body.links, false); constrain(body.limits, true);
			for (const h of body.hinges || []) { const [pl,ch,lf,rt] = body.torso, pts = nodes.map(n => n.p); const side = ReplayRagdolls.bendSide(pts, h.hip, h.knee, h.foot, pl, ch, lf, rt); if (side * h.side < 0) { const a = nodes[h.hip].p, c = nodes[h.foot].p, k = nodes[h.knee].p, f = ReplayRagdolls.facing(pts, pl, ch, lf, rt), push = -side * h.side; for (let i = 0; i < 3; i++) k[i] += f[i] * push * h.side * .9; } }
			// Overlapping spheres along each limb give the whole segment collision volume.
			for (const [i,j,radius] of body.segments) {
				const a = nodes[i], b = nodes[j], ap = a.p, bp = b.p, count = Math.max(1,Math.ceil(Math.hypot(bp[0]-ap[0],bp[1]-ap[1],bp[2]-ap[2])/radius));
				for (let s = 0; s <= count; s++) {
					const t = s/count, u = 1-t;
					for (let k = 0; k < 3; k++) { point[k] = ap[k]*u+bp[k]*t; old[k] = a.prev[k]*u+b.prev[k]*t; }
					const bx = point[0], by = point[1], bz = point[2], triangles = this.cached(point, radius) || (yield* this.cell(point, radius));
					if (ReplayRagdolls.push(point, old, radius, triangles)) { a.contact = b.contact = true; const scale = 1/(u*u*a.inverseMass+t*t*b.inverseMass), dx = (point[0]-bx)*scale, dy = (point[1]-by)*scale, dz = (point[2]-bz)*scale; ap[0] += dx*u*a.inverseMass; ap[1] += dy*u*a.inverseMass; ap[2] += dz*u*a.inverseMass; bp[0] += dx*t*b.inverseMass; bp[1] += dy*t*b.inverseMass; bp[2] += dz*t*b.inverseMass; }
					const ri = rest[i], rj = rest[j], rx = ri[0]*u+rj[0]*t, ry = ri[1]*u+rj[1]*t, rz = ri[2]*u+rj[2]*t;
					for (let n = 0; n < nodes.length; n++) {
						if (n === i || n === j || parent[n] === i || parent[n] === j || parent[i] === n || parent[j] === n) continue;
						const cx = ap[0]*u+bp[0]*t, cy = ap[1]*u+bp[1]*t, cz = ap[2]*u+bp[2]*t, node = nodes[n], q = node.p, minimum = radius+node.radius, dx = q[0]-cx, dy = q[1]-cy, dz = q[2]-cz, length = Math.sqrt(dx*dx+dy*dy+dz*dz);
						if (length >= minimum || length < .00001) continue;
						const rn = rest[n]; if (Math.hypot(rn[0]-rx, rn[1]-ry, rn[2]-rz) < minimum*1.1) continue;
						const f = (minimum-length)/length/(node.inverseMass+u*u*a.inverseMass+t*t*b.inverseMass), ex = dx*f, ey = dy*f, ez = dz*f;
						q[0] += ex*node.inverseMass; q[1] += ey*node.inverseMass; q[2] += ez*node.inverseMass;
						ap[0] -= ex*u*a.inverseMass; ap[1] -= ey*u*a.inverseMass; ap[2] -= ez*u*a.inverseMass; bp[0] -= ex*t*b.inverseMass; bp[1] -= ey*t*b.inverseMass; bp[2] -= ez*t*b.inverseMass;
					}
				}
			}
			for (const node of nodes) if (yield* this.collide(node.p,node.prev,node.radius)) node.contact = true;
		}
		for (const node of body.nodes) if (node.contact) for (let k = 0; k < 3; k++) node.prev[k] = node.p[k]-(node.p[k]-node.prev[k])*.42;
		body.frames.push(new Float32Array(body.nodes.flatMap(n => n.p))); body.frameCount++; if (body.frames.length>121) { body.frames.shift(); body.frameStart++; }
		body.bounds=[0,1,2].map(k=>Math.min(...body.nodes.map(n=>n.p[k]-n.radius))).concat([0,1,2].map(k=>Math.max(...body.nodes.map(n=>n.p[k]+n.radius))));
		// Sleep grounded bodies whose bones stay within two units for a full second.
		if (body.frameCount > 60 && body.frameCount%30 === 0 && body.nodes.some(node => node.contact)) {
			body.settled = body.nodes.every((node,i) => { let extent = 0; for (let k = 0; k < 3; k++) { let lo = Infinity, hi = -Infinity; for (let f = body.frames.length-61; f < body.frames.length; f++) { const value = body.frames[f][i*3+k]; lo = Math.min(lo,value); hi = Math.max(hi,value); } extent += (hi-lo)**2; } return extent < 4; });
		}
	}
	static facing(p, pelvis, chest, left, right) {
		const x = ReplayRenderer.normalize(p[right].map((v,k) => v-p[left][k])), up = ReplayRenderer.normalize(p[chest].map((v,k) => v-p[pelvis][k]));
		return ReplayRenderer.normalize([up[1]*x[2]-up[2]*x[1], up[2]*x[0]-up[0]*x[2], up[0]*x[1]-up[1]*x[0]]);
	}
	// Signed offset of the knee from the hip-foot line along the body's facing.
	static bendSide(p, hip, knee, foot, pelvis, chest, left, right) {
		const f = ReplayRagdolls.facing(p, pelvis, chest, left, right), a = p[hip], c = p[foot], k = p[knee], ac = c.map((v,i) => v-a[i]), l2 = ac.reduce((s,v) => s+v*v, 0) || 1, t = Math.max(0, Math.min(1, ac.reduce((s,v,i) => s+v*(k[i]-a[i]), 0)/l2));
		return [0,1,2].reduce((s,i) => s+(k[i]-a[i]-ac[i]*t)*f[i], 0);
	}
	pose(body, age) {
		let frame = Math.max(0,age*60), i = Math.floor(frame);
		while (body.frameCount <= i+1 && !body.settled && performance.now() < this.deadline) {
			if (!body.step) body.step = this.step(body);
			if (body.step.next().done) body.step = null;
		}
		// Behind (budget spent): show the newest simulated frame rather than nothing; the body
		// catches up over the next frames (a seek shows corpses collapsing quickly into place).
		if (body.frameCount <= i+1 && !body.settled) { this.pending = true; frame = Math.max(0, body.frameCount - 1); i = Math.floor(frame); }
		const poseFrame = Math.min(frame,body.frameCount); if (body.poseFrame === poseFrame) return body.matrices;
		const a = body.frames[Math.max(0,Math.min(i-body.frameStart,body.frames.length-1))], b = body.frames[Math.max(0,Math.min(i+1-body.frameStart,body.frames.length-1))], blend = frame-i;
		const points = body.selected.map((_,n) => [0,1,2].map(k => a[n*3+k]+(b[n*3+k]-a[n*3+k])*blend)), transforms = [];
		const [pelvis,chest,left,right] = body.torso; let torsoRotation;
		if ([pelvis,chest,left,right].every(i => i >= 0)) {
			const basis = p => { const x = ReplayRenderer.normalize(p[right].map((v,k) => v-p[left][k])), up = p[chest].map((v,k) => v-p[pelvis][k]), z = ReplayRenderer.normalize([x[1]*up[2]-x[2]*up[1],x[2]*up[0]-x[0]*up[2],x[0]*up[1]-x[1]*up[0]]), y = [z[1]*x[2]-z[2]*x[1],z[2]*x[0]-z[0]*x[2],z[0]*x[1]-z[1]*x[0]]; return [x,y,z]; };
			const from = basis(body.rest), to = basis(points); torsoRotation = SourceModel.quaternion([0,0,0],[0,0,0,1]);
			for (let c = 0; c < 3; c++) for (let r = 0; r < 3; r++) torsoRotation[c*4+r] = to.reduce((sum,axis,k) => sum+axis[r]*from[k][c],0);
		}
		// Rotations follow the hierarchy: each bone starts from its parent's rotation and only swings to
		// its child's new direction, so limbs keep their twist relative to the body instead of the
		// shortest arc from the death pose in world space (that spun forearms and shins around).
		const rotations = [], arc = (u, v) => { const w = 1+u[0]*v[0]+u[1]*v[1]+u[2]*v[2]; let q = [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0],w]; if (w < .00001) q = Math.abs(u[0]) < .9 ? [0,u[2],-u[1],0] : [-u[2],0,u[0],0]; const length = Math.hypot(...q); return SourceModel.quaternion([0,0,0], q.map(x => x/length)); };
		for (let j = 0; j < body.selected.length; j++) {
			const p = body.parent[j], base = p >= 0 && rotations[p] ? rotations[p] : SourceModel.quaternion([0,0,0],[0,0,0,1]), child = body.parent.indexOf(j);
			let r;
			if (torsoRotation && /pelvis|spine/i.test(body.names[j])) r = torsoRotation.slice();
			else if (child >= 0) { const u = ReplayRenderer.normalize(ReplayRenderer.point(base, body.rest[child].map((v,k) => v-body.rest[j][k]), 0)), v = ReplayRenderer.normalize(points[child].map((v,k) => v-points[j][k])); r = SourceModel.multiply(arc(u, v), base); }
			else if (p >= 0) { const u = ReplayRenderer.normalize(ReplayRenderer.point(base, body.rest[j].map((v,k) => v-body.rest[p][k]), 0)), v = ReplayRenderer.normalize(points[j].map((v,k) => v-points[p][k])); r = SourceModel.multiply(arc(u, v), base); }
			else r = base.slice();
			rotations[j] = r.slice(); const rotated = ReplayRenderer.point(r,body.rest[j]); for (let k = 0; k < 3; k++) r[12+k] = points[j][k]-rotated[k]; transforms.push(r);
		}
		const out = new Float32Array(body.model.used.length*16);
		body.model.used.forEach((id,k) => out.set(SourceModel.multiply(SourceModel.multiply(transforms[body.anchor[id]],body.world[id]),SourceModel.rows(body.model.bones[id].inverse)),k*16));
		body.poseFrame = poseFrame; body.matrices = out; return out;
	}
};

// ---- Off-main-thread jobs ---------------------------------------------------------------
// A pose worker bakes a character and its attachments together so each texture row can refer
// to its driving bone in the same tree. A separate worker steps the ragdolls.
function replayJobWorker() {
	const models = new Map(), springs = new Map(), ragdollModels = new Map(), corpseArgs = new Map(); let ragdolls = null;
	const identity=ReplayRenderer.transform([0,0,0],[0,0,0]);
	function bakeTree(tree,start,end,clock) {
		let count=0,transition=false;
		const entries=tree.map(node=>{
			const entry=models.get(node.path), model=entry.model, first=count, root=first+model.bones.length; count=root+1;
			const rows=model.rows ||= (()=>{const order=new Set(model.used);for(const b of model.bones)order.add(b.id);const lut=new Int32Array(model.bones.length);let i=0;for(const id of order)lut[id]=i++;return lut})();
			const {a,b}=node, layers=a.overlays||[],others=b?.overlays||[];
			if (a.sequence?.index!==b?.sequence?.index || layers.length!==others.length || layers.some((l,i)=>l.order!==others[i].order||l.sequence?.index!==others[i].sequence?.index))transition=true;
			return {id:node.id,first,root,rows};
		});
		const steps=Math.max(transition?2:1,Math.ceil((end-start)/.12)),samples=[];
		for(let step=0;step<=steps;step++){
			const f=step/steps,time=start+(end-start)*f, palette=new Float32Array(count*28), actors=[],rotation=new Float32Array(16);
			function write(row,m,driver,bind) {
				const o=row*28,scale=Math.hypot(m[0],m[1],m[2]);if(!(scale>0))return false;
				for(let k=0;k<12;k++)rotation[k]=m[k]/scale;
				const q=SourceAnimation.matrixQuaternion(rotation),len=Math.hypot(...q);if(!Number.isFinite(len)||Math.abs(len-1)>.001)return false;
				for(let k=0;k<4;k++)palette[o+k]=q[k]/len;
				palette[o+4]=m[12];palette[o+5]=m[13];palette[o+6]=m[14];palette[o+7]=scale;palette.set(bind,o+8);palette[o+24]=driver;
				return true;
			}
			for(let j=0;j<tree.length;j++){
				const node=tree[j],layout=entries[j],entry=models.get(node.path),model=entry.model,{a}=node,b=node.b?.model===a.model?node.b:null;
				const state=interpolateState(a,b,b?f:0,end-start,model.animation);
				let pose=SourceAnimation.sample(model,{...state,poseNames:entry.names,poseParameters:entry.params,time:clock==null?undefined:clock+time});
				let world=ReplayRenderer.transform(state.origin,state.angles),driver=-1,base,merge;
				const par=actors[node.parent],pl=entries[node.parent];
				if(par){
					const att=node.name?par.model.attachments.find(v=>v.name===node.name):node.attachment>0?par.model.attachments[node.attachment-1]:null;
					const bone=att?.bone ?? (node.name?par.model.bones.find(v=>v.name===node.name||v.name==='ValveBiped.'+node.name)?.id:undefined);
					if(bone!=null){driver=pl.first+pl.rows[bone];base=par.worldBones[bone];world=att?SourceModel.multiply(base,SourceModel.rows(att.matrix)):base.slice();
						if(node.active){const grip=model.bones.find(v=>v.name==='ValveBiped.weapon_bone');if(grip)world=SourceModel.multiply(world,SourceModel.inverse(pose.bones[grip.id]));}
					}else if(node.sprite){driver=pl.root;base=par.world;world=base.slice();}
				}
				if(node.scale!==1)for(let k=0;k<12;k++)world[k]*=node.scale;
				if(!write(layout.root,base?SourceModel.multiply(SourceModel.inverse(base),world):world,driver,identity))return null;
				const recorded=a.bones && a.bones.length===entry.boneIds.length*6;
				if(recorded){
					const inverse=SourceModel.inverse(world),overrides=[],next=b?.bones?.length===a.bones.length?b:null;
					for(let k=0;k<entry.boneIds.length;k++){const id=entry.boneIds[k];if(id<0)continue;const off=k*6;
						const point=(s)=>s.origin.map((x,d)=>x+s.bones[off+d]/32),rot=s=>SourceAnimation.matrixQuaternion(ReplayRenderer.transform([0,0,0],[0,1,2].map(d=>s.bones[off+3+d]/128)));
						let pos=point(a),q=rot(a);if(next && f){const p=point(b);pos=pos.map((v,d)=>v+(p[d]-v)*f);q=SourceAnimation.slerp(q,rot(b),f);}
						const m=SourceModel.quaternion(pos,q);for(let d=0;d<12;d++)m[d]*=node.scale;overrides[id]=SourceModel.multiply(inverse,m);
					}pose=SourceAnimation.overrideBones(model,pose,overrides);
				}
				let spring=springs.get(node.id);if(!spring||spring.path!==node.path){spring=new Map();spring.path=node.path;springs.set(node.id,spring);}
				pose=SourceAnimation.procedural(model,pose,world,time,spring);
				if(par&&node.merge){merge=SourceAnimation.mergeMap(model,par.model);pose=SourceAnimation.boneMerge(model,pose,par.model,par.pose,par.world,world);}
				const worldBones=pose.bones.map(m=>SourceModel.multiply(world,m)), ancestor=[];
				for(const bone of model.bones){
					const id=bone.id, matched=merge?.[id]??-1, inherited=matched>=0?id:ancestor[bone.parent]??-1;ancestor[id]=inherited;
					let local=pose.bones[id],ref=layout.root;
					if(matched>=0){ref=pl.first+pl.rows[matched];local=identity;}
					else if(inherited>=0){ref=layout.first+layout.rows[inherited];local=SourceModel.multiply(SourceModel.inverse(pose.bones[inherited]),pose.bones[id]);}
					else if(recorded && (!par || entry.boneIds.includes(id))){ref=-1;local=worldBones[id];}
					else if(recorded && bone.parent>=0){ref=layout.first+layout.rows[bone.parent];local=pose.locals[id];}
					if(!write(layout.first+layout.rows[id],local,ref,bone.bindInverse ||= SourceModel.rows(bone.inverse)))return null;
				}
				actors.push({model,pose,world,worldBones});
			}
			samples.push({palette});
		}
		return {entries,samples};
	}
	function corpse(request, deadline) {
		const ragdoll = ragdolls; ragdoll.deadline = deadline; ragdoll.pending = false;
		if (request.create) { corpseArgs.set(request.key, request.create); if (corpseArgs.size > 512) corpseArgs.delete(corpseArgs.keys().next().value); }
		let body = ragdoll.bodies.get(request.key);
		if (body && Math.floor(Math.max(0, request.age) * 60) < body.frameStart) { ragdoll.bodies.delete(request.key); body = undefined; }
		if (body === undefined) {
			const args = corpseArgs.get(request.key), model = args && ragdollModels.get(args.path); if (!args || !model) return {key:request.key, missing:true};
			while (ragdoll.bodies.size >= 96) ragdoll.bodies.delete(ragdoll.bodies.keys().next().value);
			body = ragdoll.create(request.key, model, args.world, args.velocities, args.impacts);
		} else { ragdoll.bodies.delete(request.key); ragdoll.bodies.set(request.key, body); }
		if (!body) return {key:request.key, empty:true};
		const matrices = ragdoll.pose(body, request.age); if (!matrices) return {key:request.key, behind:true};
		const settled = body.settled && request.age >= (body.frameCount - 1) / 60;
		return {key:request.key, age:request.age, matrices:matrices.slice(), bounds:body.bounds, behind:ragdoll.pending, settledAge:settled ? (body.frameCount - 1) / 60 : null};
	}
	onmessage = ({data}) => {
		try {
			if (data.type === 'model') models.set(data.path, data);
			else if (data.type === 'ragdollModel') ragdollModels.set(data.path, data.model);
			else if (data.type === 'collision') { ragdolls = new ReplayRagdolls({collision:data.collision}); ragdolls.grid().next(); }
			else if (data.type === 'reset') springs.clear();
			else if (data.type === 'clearCorpses') { if (ragdolls) ragdolls.bodies.clear(); corpseArgs.clear(); }
			else if (data.type === 'poses') {
				const start=performance.now(),results=data.trees.map(tree=>bakeTree(tree,data.start,data.end,data.clock)).filter(Boolean);
				postMessage({type:'poses',request:data.request,results,ms:performance.now()-start},results.flatMap(r=>r.samples.map(s=>s.palette.buffer)));
			} else if (data.type === 'corpses') {
				const start = performance.now(), deadline = start + data.budget, results = [], transfer = [];
				for (let i = 0; i < data.list.length; i++) {
					const now = performance.now(), result = corpse(data.list[i], now + Math.max(0, deadline - now) / (data.list.length - i));
					results.push(result); if (result.matrices) transfer.push(result.matrices.buffer);
				}
				postMessage({type:'corpses', serial:data.serial, results, ms:performance.now() - start}, transfer);
			}
		} catch (error) { postMessage({type:'error', message:String(error && error.stack || error)}); }
	};
}
globalThis.ReplayJobs = class {
	constructor(map, invalidate) {
		this.invalidate = invalidate; this.pending=new Map(); this.request=0; this.corpses = new Map(); this.corpseSent = new Set(); this.poseTime = 0; this.ragdollTime = 0;
		const object = value => '{' + Object.entries(value).map(([name, fn]) => { const source = fn.toString(); return /^(?:async\s+)?\*?\w+\s*\(/.test(source) ? source : JSON.stringify(name) + ':' + source; }).join(',') + '}';
		const definitions = ['clamp=(x,a,b)=>Math.max(a,Math.min(b,x))','interpolateState=('+object({interpolateState:ReplayScene.interpolateState})+').interpolateState', 'SourceIO=' + object(SourceIO), 'SourceModel=' + object(SourceModel), 'SourceAnimation=' + object(SourceAnimation),
			'ReplayRenderer=' + object({transform:ReplayRenderer.transform, point:ReplayRenderer.point, normalize:ReplayRenderer.normalize}), 'ReplayRagdolls=' + ReplayRagdolls.toString()].map(source => 'const ' + source + ';').join('\n');
		const url = URL.createObjectURL(new Blob([definitions, '\n(', replayJobWorker.toString(), ')();'], {type:'text/javascript'}));
		const count = Math.max(1, Math.min(3, (navigator.hardwareConcurrency || 2) - 2));
		const make = () => { const worker = new Worker(url); worker.onerror = event => this.fail(event.message || 'worker error'); worker.onmessage = ({data}) => this.receive(worker, data); worker.busy = false; worker.models = new Set(); return worker; };
		this.workers = Array.from({length:count}, make); this.ragdollWorker = make(); URL.revokeObjectURL(url);
		// The ragdoll worker holds its own copy of the world collision; the main thread keeps one for
		// the single-thread fallback and the particle/pick code.
		this.ragdollWorker.postMessage({type:'collision', collision:map.collision.map(group => ({vertices:group.vertices}))});
		this.live = true; this.pendingCorpses = []; this.serial = 0;
	}
	fail(message) { if (!this.live) return; console.warn('Replay job workers disabled:', message); this.dispose(); this.invalidate(); }
	slot(path) { let h = 0; for (let i = 0; i < path.length; i++) h = h * 31 + path.charCodeAt(i) | 0; return Math.abs(h) % this.workers.length; }
	async bake(frame,trees,scene) {
		const groups=this.workers.map(()=>[]),pageKey={};
		for(const tree of trees.values()) groups[this.slot(tree[0].path)].push(tree);
		await Promise.all(groups.map(async(list,i)=>{
			if(!list.length)return;
			const worker=this.workers[i];
			for(const tree of list)for(const node of tree)if(!worker.models.has(node.path)){
				const m=scene.models[node.path],index=node.a.model;worker.models.add(node.path);
				worker.postMessage({type:'model',path:m.path,model:{path:m.path,bones:m.bones,used:m.used,animation:m.animation,attachments:m.attachments},names:scene.poseNames[index],params:scene.manifest.models[index].poseParameters,boneIds:scene.poseBoneIds[index]});
			}
			const request=++this.request,results=await new Promise(resolve=>{this.pending.set(request,resolve);worker.postMessage({type:'poses',request,trees:list,start:frame.sampleTime,end:frame.nextTime,clock:scene.manifest.clock?.time});});
			for(const {entries,samples} of results){
				for(const sample of samples)sample.pageKey=pageKey;
				for(const entry of entries)frame.prepared.poses.set(entry.id,{...entry,samples});
			}
		}));
	}
	queueCorpse(request, model) {
		if (request.create && !this.ragdollWorker.models.has(model.path)) { this.ragdollWorker.models.add(model.path); try { this.ragdollWorker.postMessage({type:'ragdollModel', path:model.path, model:{path:model.path, bones:model.bones, used:model.used, physics:model.physics, collision:model.collision, hitboxSets:model.hitboxSets}}); } catch (error) { this.fail(error.message); return; } }
		this.pendingCorpses.push(request);
	}
	reset() { if (this.live) for (const worker of this.workers) worker.postMessage({type:'reset'}); }
	clearCorpses() { if (this.live) this.ragdollWorker.postMessage({type:'clearCorpses'}); this.corpses.clear(); this.corpseSent.clear(); }
	flush(playing) {
		if (!this.live) return; this.serial++;
		try {
		const list = this.pendingCorpses; this.pendingCorpses = [];
		if (list.length && !this.ragdollWorker.busy) { this.ragdollWorker.busy = true; this.ragdollWorker.postMessage({type:'corpses', serial:this.serial, list, budget:playing ? 8 : 40}); }
		} catch (error) { this.fail(error.message); }
	}
	receive(worker, data) {
		if (data.type === 'error') { this.fail(data.message); return; }
		worker.busy = false;
		if (data.type === 'poses') { this.poseTime += data.ms || 0; this.pending.get(data.request)?.(data.results);this.pending.delete(data.request);return; }
		else if (data.type === 'corpses') { this.ragdollTime += data.ms || 0; for (const result of data.results) { if (result.missing) this.corpseSent.delete(result.key); else if (result.matrices) this.corpses.set(result.key, result); } }
		this.invalidate();
	}
	dispose() { this.live = false; for (const worker of [...this.workers, this.ragdollWorker]) worker.terminate(); for(const resolve of this.pending.values())resolve([]);this.pending.clear();this.corpses.clear(); }
};
