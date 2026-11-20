'use strict';
// Valve studio.h / optimize.h: retain mesh materials, skin families and UVs.
globalThis.SourceModel = {
	multiply(a, b, out = new Float32Array(16), offset = 0, source = 0) {
		// Column-major 4x4 product, unrolled (hot path: every bone of every actor, every frame).
		const a0=a[0],a1=a[1],a2=a[2],a3=a[3],a4=a[4],a5=a[5],a6=a[6],a7=a[7],a8=a[8],a9=a[9],a10=a[10],a11=a[11],a12=a[12],a13=a[13],a14=a[14],a15=a[15];
		for (let c = 0; c < 16; c += 4) { const i=source+c,o=offset+c,b0=b[i],b1=b[i+1],b2=b[i+2],b3=b[i+3]; out[o]=a0*b0+a4*b1+a8*b2+a12*b3; out[o+1]=a1*b0+a5*b1+a9*b2+a13*b3; out[o+2]=a2*b0+a6*b1+a10*b2+a14*b3; out[o+3]=a3*b0+a7*b1+a11*b2+a15*b3; }
		return out;
	},
	rows(a) { return new Float32Array([a[0],a[4],a[8],0,a[1],a[5],a[9],0,a[2],a[6],a[10],0,a[3],a[7],a[11],1]); },
	inverse(a) {
		// Affine fast path (bones, entity transforms): invert the 3x3 block and the translation.
		if (a[3] === 0 && a[7] === 0 && a[11] === 0 && a[15] === 1) {
			const m0=a[0],m1=a[1],m2=a[2],m4=a[4],m5=a[5],m6=a[6],m8=a[8],m9=a[9],m10=a[10];
			const c0=m5*m10-m6*m9,c1=m2*m9-m1*m10,c2=m1*m6-m2*m5,det=m0*c0+m4*c1+m8*c2;
			if (!(Math.abs(det) > 1e-30)) throw Error('不可逆的模型或镜头矩阵');
			const k=1/det,out=new Float32Array(16);
			out[0]=c0*k; out[1]=c1*k; out[2]=c2*k;
			out[4]=(m6*m8-m4*m10)*k; out[5]=(m0*m10-m2*m8)*k; out[6]=(m2*m4-m0*m6)*k;
			out[8]=(m4*m9-m5*m8)*k; out[9]=(m1*m8-m0*m9)*k; out[10]=(m0*m5-m1*m4)*k;
			const x=a[12],y=a[13],z=a[14];
			out[12]=-(out[0]*x+out[4]*y+out[8]*z); out[13]=-(out[1]*x+out[5]*y+out[9]*z); out[14]=-(out[2]*x+out[6]*y+out[10]*z); out[15]=1;
			return out;
		}
		const rows = Array.from({length:4}, (_, r) => [a[r],a[4+r],a[8+r],a[12+r],...Array.from({length:4}, (_, c) => Number(c === r))]);
		for (let c = 0; c < 4; c++) { let pivot = c; for (let r = c+1; r < 4; r++) if (Math.abs(rows[r][c]) > Math.abs(rows[pivot][c])) pivot = r; [rows[c],rows[pivot]] = [rows[pivot],rows[c]]; const divisor = rows[c][c]; if (Math.abs(divisor) < 1e-12) throw Error('不可逆的模型或镜头矩阵'); rows[c] = rows[c].map(v => v/divisor); for (let r = 0; r < 4; r++) if (r !== c) { const scale = rows[r][c]; rows[r] = rows[r].map((v, k) => v-scale*rows[c][k]); } }
		return new Float32Array(Array.from({length:16}, (_, i) => rows[i%4][4+Math.floor(i/4)]));
	},
	quaternion(pos, q) { const [x,y,z,w] = q; return new Float32Array([1-2*(y*y+z*z),2*(x*y+z*w),2*(x*z-y*w),0,2*(x*y-z*w),1-2*(x*x+z*z),2*(y*z+x*w),0,2*(x*z+y*w),2*(y*z-x*w),1-2*(x*x+y*y),0,...pos,1]); },
	async load(library, path) {
		if (/\.(vmt|spr)$/.test(path)) return SourceSprite.load(library,path);
		const [mdl, vvd, vtx] = await Promise.all([library.read(path), library.read(path.slice(0, -4) + '.vvd'), library.read(path.slice(0, -4) + '.dx90.vtx')]);
		if (!mdl || !vvd || !vtx) throw Error('模型文件不完整：' + path);
		const m = SourceIO.view(mdl), v = SourceIO.view(vvd), x = SourceIO.view(vtx), i = (d, o) => d.getInt32(o, true), u = (d, o) => d.getUint16(o, true), f = SourceIO.floats;
		// L4D2 also ships v44 and v45 props with these studio mesh and bone layouts.
		if (SourceIO.string(mdl, 0).slice(0, 4) !== 'IDST' || ![44, 45, 46, 47, 48, 49].includes(i(m, 4))) throw Error('MDL 格式不支持：' + path);
		if (i(m, 8) !== i(v, 8) || i(m, 8) !== i(x, 16)) throw Error('模型各文件校验值不一致：' + path);
		const bones = [], attachments = [], hitboxSets = [];
		for (let n = 0; n < i(m, 156); n++) { const at = i(m, 160) + n * 216; bones.push({id:n, name:SourceIO.string(mdl, at + i(m, at)), parent:i(m, at + 4), flags:i(m, at + 160), inverse:f(m, at + 96, 12), position:f(m, at+32,3), quaternion:f(m, at+44,4), rotation:f(m, at+60,3), positionScale:f(m, at+72,3), rotationScale:f(m, at+84,3), alignment:f(m,at+144,4), proc:i(m, at + 164)});
			// studio.h procedural bones: quaternion-interpolated helpers (2) and jiggle bones (5).
			const bone = bones.at(-1), base = at + i(m, at + 168);
			if (bone.proc === 2) { const at2 = base + i(m, base + 8); bone.quatInterp = {control:i(m, base), triggers:Array.from({length:i(m, base + 4)}, (_, k) => { const t = at2 + k * 48; return {invTolerance:f(m, t, 1)[0], trigger:f(m, t + 4, 4), pos:f(m, t + 20, 3), quat:f(m, t + 32, 4)}; })}; }
			else if (bone.proc === 5) { const v = f(m, base + 4, 29); bone.jiggle = {flags:i(m, base), length:v[0], tipMass:v[1], yawStiffness:v[2], yawDamping:v[3], pitchStiffness:v[4], pitchDamping:v[5], alongStiffness:v[6], alongDamping:v[7], angleLimit:v[8], minYaw:v[9], maxYaw:v[10], minPitch:v[13], maxPitch:v[14], baseMass:v[17], baseStiffness:v[18], baseDamping:v[19], baseLimits:[v.slice(20,23),v.slice(23,26),v.slice(26,29)]}; }
			else bone.proc = 0;
		}
		for (let n = 0; n < i(m, 240); n++) { const at = i(m, 244) + n * 92; attachments.push({name:SourceIO.string(mdl, at + i(m, at)), bone:i(m, at + 8), matrix:f(m, at + 12, 12)}); }
		const names = [], dirs = [], skins = [];
		for (let n = 0; n < i(m, 204); n++) { const at = i(m, 208) + n * 64; names.push(SourceIO.string(mdl, at + i(m, at))); }
		for (let n = 0; n < i(m, 212); n++) dirs.push(SourceIO.string(mdl, i(m, i(m, 216) + n * 4)));
		for (let n = 0; n < i(m, 224); n++) skins.push(Array.from({length:i(m, 220)}, (_, k) => u(m, i(m, 228) + (n * i(m, 220) + k) * 2)));
		let vertexOrder = Array.from({length:i(v, 16)}, (_, k) => k);
		if (i(v, 48)) { vertexOrder = []; for (let n = 0; n < i(v, 48); n++) { const at = i(v, 52) + n * 12, start = i(v, at + 4); for (let k = 0; k < i(v, at + 8); k++) vertexOrder.push(start + k); } }
		const groups = [], used = new Set(), eyeballs = []; let lightingMesh = 0;
		if (i(m, 232) !== i(x, 28)) throw Error('模型部件数不匹配：' + path);
		for (let body = 0; body < i(m, 232); body++) {
			const bp = i(m, 236) + body * 16, vb = i(x, 32) + body * 8, variants = i(m, bp + 4), base = i(m, bp + 8);
			for (let variant = 0; variant < variants; variant++) {
				const mo = bp + i(m, bp + 12) + variant * 148, vm = vb + i(x, vb + 4) + variant * 8, level = 0, lod = vm + i(x, vm + 4) + level * 12;
				let lightingGroup = lightingMesh;
				for (let n = 0; n < i(x, vm); n++) { const levelHeader = vm + i(x, vm + 4) + n * 12; for (let mesh = 0; mesh < i(x, levelHeader); mesh++) lightingMesh += i(x, levelHeader + i(x, levelHeader + 4) + mesh * 9); }
				if (!i(m, mo + 72) || !i(m, mo + 80)) continue;
				// mstudioeyeball_t (172 bytes, off mstudiomodel_t +100/+104): bone, org, zoffset, radius,
				// up, forward (bone space), iris material, iris_scale. Meshes with materialtype 1 are eyeballs.
				const eyeBase = eyeballs.length;
				for (let k = 0; k < i(m, mo + 100); k++) { const at = mo + i(m, mo + 104) + k * 172, e = f(m, at + 8, 11); eyeballs.push({name:SourceIO.string(mdl, at + i(m, at)), bone:i(m, at + 4), org:e.slice(0, 3), zoffset:e[3], radius:e[4], up:e.slice(5, 8), forward:e.slice(8, 11), texture:i(m, at + 52), irisScale:f(m, at + 60, 1)[0]}); }
				for (let mesh = 0; mesh < i(m, mo + 72); mesh++) {
					const mm = mo + i(m, mo + 76) + mesh * 116, mx = lod + i(x, lod + 4) + mesh * 9, triangles = [], lighting = new Map();
					for (let group = 0; group < i(x, mx); group++) {
						const sg = mx + i(x, mx + 4) + group * 25, ids = Array.from({length:i(x, sg)}, (_, j) => u(x, sg + i(x, sg + 4) + j * 9 + 4) + i(m, mm + 12) + i(m, mo + 84) / 48);
						for (let j = 0; j < ids.length; j++) if (!lighting.has(ids[j])) lighting.set(ids[j],[lightingGroup,j]); lightingGroup++;
						for (let strip = 0; strip < i(x, sg + 16); strip++) {
							const st = sg + i(x, sg + 20) + strip * 27, count = i(x, st), first = i(x, st + 4), flags = vtx[st + 18];
							const ix = Array.from({length:count}, (_, j) => u(x, sg + i(x, sg + 12) + (first + j) * 2));
							if (flags & 2) for (let j = 0; j < ix.length - 2; j++) { const tri = j % 2 ? [ix[j + 1], ix[j], ix[j + 2]] : ix.slice(j, j + 3); if (new Set(tri).size === 3) for (const k of tri) triangles.push(ids[k]); }
							else for (const k of ix) triangles.push(ids[k]);
						}
					}
					if (!triangles.length) continue;
					const ids = [...new Set(triangles)].sort((a, b) => a - b), remap = new Map(ids.map((n, k) => [n, k])), vertices = [], normals = [], uv = [], weights = [], boneIds = [];
					for (const id of ids) { const at = i(v, 56) + vertexOrder[id] * 48; vertices.push(...f(v, at + 16, 3)); normals.push(...f(v, at + 28, 3)); uv.push(...f(v, at + 40, 2)); const weight=f(v,at,3);weights.push(...weight); for (let k = 0; k < 3; k++) { const bone = weight[k]>0?vvd[at + 12 + k]:0; boneIds.push(bone); if(weight[k]>0)used.add(bone); } }
					groups.push({body, variant, base, variants, lod:level, materialIndex:i(m, mm), eyeball:i(m, mm + 24) === 1 ? eyeBase + i(m, mm + 28) : -1, vertices:new Float32Array(vertices), normals:new Float32Array(normals), uv:new Float32Array(uv), weights:new Float32Array(weights), bones:new Uint16Array(boneIds), indices:new Uint32Array(triangles.map(k => remap.get(k))), lightingIndices:new Uint32Array(ids.flatMap(id => lighting.get(id)))});
				}
			}
		}
		const materials = [];
		const needed = new Set(); for (const g of groups) { needed.add(g.materialIndex); for (const skin of skins) needed.add(skin[g.materialIndex]); }
		for (const n of needed) {
			if (!names[n]) continue; let materialPath = names[n];
			for (const dir of dirs) { const candidate = SourceIO.path(dir + names[n]); if (await library.read('materials/' + candidate + '.vmt')) { materialPath = candidate; break; } }
			materials[n] = await library.material(materialPath);
		}
		const replacements = {};
		for (const level of new Set(groups.map(g => g.lod))) {
			const at = i(x, 24) + level * 8, values = {};
			for (let n = 0; n < i(x, at); n++) { const entry = at + i(x, at + 4) + n * 6; values[u(x, entry)] = await library.material(SourceIO.string(vtx, entry + i(x, entry + 2))); }
			replacements[level] = values;
		}
		const animation = await SourceAnimation.load(library,path,mdl,bones);
		for (let n = 0; n < i(m,172); n++) { const at = i(m,176)+n*12; hitboxSets.push({name:SourceIO.string(mdl,at+i(m,at)), boxes:Array.from({length:i(m,at+4)}, (_, k) => { const p = at+i(m,at+8)+k*68; return {bone:i(m,p),group:i(m,p+4),mins:f(m,p+8,3),maxs:f(m,p+20,3)}; })}); }
		// studiomdl/VTX triangles are clockwise-front (Direct3D); the renderer culls with GL's CCW
		// front faces, so every triangle is reversed, as the engine's culling would see it. No
		// normal-based vote: a per-triangle vote flipped faces whose smoothed normals disagree
		// with the winding (sockets, bevels, thin walls) and culling then removed their outside.
		// windingMixed counts those triangles (diagnostic only; c6m3: 0.3 % of all triangles).
		let mixed = 0;
		for (const group of groups) {
			const v = group.vertices, n = group.normals, ix = group.indices;
			for (let t = 0; t < ix.length; t += 3) {
				const a = ix[t]*3, b = ix[t+1]*3, c = ix[t+2]*3, ax = v[b]-v[a], ay = v[b+1]-v[a+1], az = v[b+2]-v[a+2], bx = v[c]-v[a], by = v[c+1]-v[a+1], bz = v[c+2]-v[a+2];
				if ((ay*bz-az*by)*(n[a]+n[b]+n[c])+(az*bx-ax*bz)*(n[a+1]+n[b+1]+n[c+1])+(ax*by-ay*bx)*(n[a+2]+n[b+2]+n[c+2]) > 0) mixed++;
				const swap = ix[t+1]; ix[t+1] = ix[t+2]; ix[t+2] = swap;
			}
		}
		let physics = [], collision = null;
		const physicsPaths = [path]; for (let n = 0; n < i(m,336); n++) { const at = i(m,340)+n*8; physicsPaths.push(SourceIO.path(SourceIO.string(mdl,at+i(m,at+4)))); }
		for (const name of physicsPaths) { const bytes = await library.read(name.slice(0,-4)+'.phy'); if (!bytes) continue; collision = SourcePhysics.read(bytes); physics = collision.bodies; break; }
		const model = {path, eyeballs, windingMixed:mixed, checksum:i(m, 8), bones, used:[...used].sort((a, b) => a - b), groups, materials, skins, attachments, replacements, physics, collision, animation, hitboxSets};
		return model;
	}
};
