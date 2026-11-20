'use strict';
globalThis.SourceMap = {
	ambient(map, point) {
		const lighting = map.lighting; if (!lighting) return null;
		let leaf = lighting.root;
		while (leaf >= 0) { const node = leaf * 3, plane = lighting.nodes[node] * 4, p = lighting.planes; leaf = lighting.nodes[node + (p[plane]*point[0]+p[plane+1]*point[1]+p[plane+2]*point[2] < p[plane+3] ? 2 : 1)]; }
		leaf = -1 - leaf;
		const index = lighting.index, bounds = lighting.bounds, samples = lighting.samples, cube = new Float32Array(18);
		if (!index[leaf*2] && index[leaf*2+1]) leaf = index[leaf*2+1];
		let weightSum = 0;
		for (let i = 0; i < index[leaf*2]; i++) {
			const at = (index[leaf*2+1]+i)*28; let distance = 0;
			for (let axis = 0; axis < 3; axis++) { const min = bounds[leaf*6+axis], max = bounds[leaf*6+axis+3], delta = min+(max-min)*samples[at+24+axis]/255-point[axis]; distance += delta*delta; }
			// Engine leaf-ambient interpolation uses all samples, weighted by 1/(distance squared + 1).
			const weight = 1/(distance+1); weightSum += weight;
			for (let side = 0; side < 6; side++) { const start = at+side*4, exponent = samples[start+3] > 127 ? samples[start+3]-256 : samples[start+3], scale = 2**exponent*weight; for (let c = 0; c < 3; c++) cube[side*3+c] += samples[start+c]*scale; }
		}
		if (weightSum) for (let i = 0; i < cube.length; i++) cube[i] /= weightSum;
		return cube;
	},
	// Segment test against the world BSP (solid/opaque leaves), as the engine's light visibility trace.
	blocked(map, a, b) {
		const L = map.lighting, nodes = L.nodes, planes = L.planes, contents = L.contents;
		const walk = (node, ax, ay, az, bx, by, bz) => {
			while (node >= 0) {
				const at = nodes[node*3]*4, nx = planes[at], ny = planes[at+1], nz = planes[at+2], dist = planes[at+3];
				const da = nx*ax+ny*ay+nz*az-dist, db = nx*bx+ny*by+nz*bz-dist;
				if (da >= -.03 && db >= -.03) { node = nodes[node*3+1]; continue; }
				if (da < .03 && db < .03) { node = nodes[node*3+2]; continue; }
				const f = da / (da - db), mx = ax+(bx-ax)*f, my = ay+(by-ay)*f, mz = az+(bz-az)*f, first = da >= 0 ? 1 : 2;
				if (walk(nodes[node*3+first], ax, ay, az, mx, my, mz)) return true;
				node = nodes[node*3+3-first]; ax = mx; ay = my; az = mz;
			}
			return (contents[-1-node] & 0x81) !== 0; // CONTENTS_SOLID | CONTENTS_OPAQUE
		};
		return walk(L.root, a[0], a[1], a[2], b[0], b[1], b[2]);
	},
	// Engine dynamic-model lighting (ComputeLightingState): every visible point/spot light's
	// intensity at the model's lighting origin; the strongest `count` stay local lights, the rest
	// are folded into the ambient cube (AddWorldLightToAmbientCube). Sky lights are handled by the
	// renderer's sun (shadow-mapped). Returns {lights:[...], cube:Float32Array(18) addition}.
	worldLights(map, point, count = 4) {
		const L = map.lighting; if (!L?.lights?.length) return null;
		const found = [], cube = new Float32Array(18), cache = L.visibility || (L.visibility = new Map());
		if (cache.size > 65536) cache.clear();
		const cell = Math.round(point[0]/32)+','+Math.round(point[1]/32)+','+Math.round(point[2]/32);
		for (let i = 0; i < L.lights.length; i++) {
			const light = L.lights[i]; if (light.type !== 1 && light.type !== 2) continue;
			const dx = point[0]-light.origin[0], dy = point[1]-light.origin[1], dz = point[2]-light.origin[2], d2 = dx*dx+dy*dy+dz*dz, d = Math.sqrt(d2) || 1;
			if (light.radius > 0 && d2 > light.radius*light.radius) continue;
			const [c, l, q] = light.attenuation; let ratio = 1 / Math.max(1e-6, c + l*d + q*d2);
			if (light.type === 2) {
				const dot = (dx*light.normal[0]+dy*light.normal[1]+dz*light.normal[2]) / d; if (dot <= light.stopdot2) continue;
				ratio *= light.exponent ? Math.pow(dot, light.exponent) : 1;
				if (dot <= light.stopdot) ratio *= (dot - light.stopdot2) / Math.max(1e-6, light.stopdot - light.stopdot2);
			}
			const strength = Math.max(...light.intensity) * ratio; if (strength < 1e-4) continue;
			const key = cell + '|' + i; let visible = cache.get(key);
			if (visible === undefined) { visible = !this.blocked(map, light.origin.map((v, k) => v + [dx,dy,dz][k]/d), point.map((v, k) => v - [dx,dy,dz][k]/d)); cache.set(key, visible); }
			if (visible) found.push({light, strength, ratio, direction:[-dx/d, -dy/d, -dz/d]});
		}
		found.sort((a, b) => b.strength - a.strength);
		for (const extra of found.slice(count)) for (let side = 0; side < 6; side++) {
			const axis = side >> 1, sign = side & 1 ? -1 : 1, weight = Math.max(0, extra.direction[axis]*sign);
			if (weight) for (let k = 0; k < 3; k++) cube[side*3+k] += extra.light.intensity[k]*extra.ratio*weight;
		}
		return {lights:found.slice(0, count).map(entry => entry.light), cube};
	},
	vertexLighting(bytes) {
		const data = SourceIO.view(bytes), meshes = [];
		for (let i = 0; i < data.getUint32(20,true); i++) {
			const at = 40+i*28, count = data.getUint32(at+4,true), offset = data.getUint32(at+8,true), stride = data.getUint32(12,true), colors = new Float32Array(count*3);
			// VRAD stores BGRA vertex light with gamma 2.2 and overbright factor 1/2.
			for (let vertex = 0; vertex < count; vertex++) for (let c = 0; c < 3; c++) colors[vertex*3+c] = (bytes[offset+vertex*stride+2-c]*2/255)**2.2;
			meshes.push({lod:data.getUint32(at,true), colors});
		}
		return meshes;
	},
	inSky(map, point) {
		const partition=map.sky?.partition;if(!partition)return false;let node=partition.root;
		while(node>=0){const at=node*4,plane=partition.planes;node=partition.children[node*2+(plane[at]*point[0]+plane[at+1]*point[1]+plane[at+2]*point[2]<plane[at+3]?1:0)];}
		return node===-2;
	},
	skyTransform(map, matrix) {
		const sky=map.sky,world=matrix.slice();for(let i=0;i<12;i++)world[i]*=sky.scale;for(let i=0;i<3;i++)world[12+i]=(world[12+i]-sky.origin[i])*sky.scale;return world;
	},
	nav(bytes) {
		if (!bytes) return new Float32Array(); const d = SourceIO.view(bytes); let p = 0;
		const u32 = () => { const x = d.getUint32(p, true); p += 4; return x; }, u16 = () => { const x = d.getUint16(p, true); p += 2; return x; }, u8 = () => bytes[p++], skip = n => { p += n; };
		if (u32() !== 0xfeedface || u32() !== 16 || u32() !== 14) throw Error('NAV 格式不支持');
		skip(5); for (let n = u16(); n > 0; n--) skip(u16()); skip(1); while (u8()); for (let n = u16(); n > 0; n--) skip(u16());
		const result = [];
		for (let n = u32(); n > 0; n--) {
			skip(8); const [nx, ny, nz, sx, sy, sz, ne, sw] = SourceIO.floats(d, p, 8); skip(32);
			result.push(nx,ny,nz,sx,ny,ne,sx,sy,sz,nx,ny,nz,sx,sy,sz,nx,sy,sw);
			for (let k = 0; k < 4; k++) skip(4 * u32()); skip(17 * u8());
			for (let k = u32(); k > 0; k--) { skip(10); skip(5 * u8()); } skip(2);
			for (let k = 0; k < 2; k++) skip(4 * u32()); skip(30); skip(5 * u32()); skip(4);
		}
		if (p > bytes.length) throw Error('NAV 数据不完整'); return new Float32Array(result);
	},
	async load(library, name) {
		library.embedded.clear(); library.materials.clear(); library.textures.clear(); library.models.clear(); library.animations.clear(); library.warnings.clear();
		library.progress('读取地图 ' + name + '…'); const bytes = await library.read('maps/' + name + '.bsp'); if (!bytes) throw Error('所选游戏目录没有地图：' + name);
		const b = SourceIO.view(bytes), I = (d, o) => d.getInt32(o, true), U = (d, o) => d.getUint16(o, true), F = SourceIO.floats;
		if (SourceIO.text(bytes.subarray(0, 4)) !== 'VBSP' || I(b, 4) !== 21) throw Error('需要 L4D2 BSP v21 地图');
		function lump(n) { const p = 8 + n * 16, at = I(b, p + 4), length = I(b, p + 8); if (I(b, p + 12)) throw Error('地图包含尚未支持的压缩 BSP lump ' + n); return bytes.subarray(at, at + length); }
		const pak = lump(40); if (pak.length) library.zip(pak.slice());
		const definitions = (SourceIO.text(lump(0)).match(/\{[^{}]*\}/g) || []).map(block => SourceIO.keys('entity '+block).values);
		const vector = (value, fallback = '0 0 0') => (value || fallback).trim().split(/\s+/).map(Number);
		const entities = definitions.filter(e => /\.(mdl|vmt|spr)$/.test(e.model || '') || e.model?.startsWith('*')).map(e => ({classname:e.classname, name:e.targetname, model:SourceIO.path(e.model), origin:vector(e.origin), angles:vector(e.angles), skin:Number(e.skin || 0), body:Number(e.body || 0), sequence:e.defaultanim, alpha:e.rendermode === '10' || e.startdisabled === '1' ? 0 : e.rendermode && e.rendermode !== '0' ? Number(e.renderamt ?? 255)/255 : 1}));
		// The target names the brush used to mask the room at a distance in the game.
		const brushByName = new Map(definitions.filter(e => e.targetname && e.model?.startsWith('*')).map(e => [e.targetname.toLowerCase(), e.model])), portalWindows = {};
		for (const e of definitions) if (e.classname === 'func_areaportalwindow') {
			const model = brushByName.get(String(e.target || '').toLowerCase());
			if (model) portalWindows[model] = true;
		}
		const vert = SourceIO.view(lump(3)), edge = SourceIO.view(lump(12)), surf = SourceIO.view(lump(13)), face = SourceIO.view(!lump(8).length && lump(58).length ? lump(58) : lump(7)), tex = SourceIO.view(lump(6)), td = SourceIO.view(lump(2)), names = lump(43), table = SourceIO.view(lump(44)), planes = SourceIO.view(lump(1)), disp = SourceIO.view(lump(26)), dv = SourceIO.view(lump(33)), models = SourceIO.view(lump(14)), light = lump(8).length ? lump(8) : lump(53);
		const nodes = SourceIO.view(lump(5)), leaves = SourceIO.view(lump(10)), leafFaces = SourceIO.view(lump(16));
		const leafArea = point => { let n = I(models, 36); while (n >= 0) { const at = n * 32, plane = I(nodes, at) * 20, normal = F(planes, plane, 3); n = I(nodes, at + 4 + (normal.reduce((sum, v, k) => sum + v * point[k], 0) < planes.getFloat32(plane + 12, true) ? 4 : 0)); } return U(leaves, (-1 - n) * 32 + 6) & 511; };
		const skyDefinition = definitions.find(e => e.classname === 'sky_camera'), sky = skyDefinition ? {origin:vector(skyDefinition.origin), scale:Number(skyDefinition.scale || 16)} : null;
		const skyArea = sky ? leafArea(sky.origin) : -1, skyFaces = new Set();
		if(sky){const children=[],splits=[];
			// Keep only BSP splits that separate the sky-camera area from the playable map.
			const partition=node=>{if(node<0)return (U(leaves,(-1-node)*32+6)&511)===skyArea?-2:-1;const at=node*32,front=partition(I(nodes,at+4)),back=partition(I(nodes,at+8));if(front===back)return front;const index=children.length/2;children.push(front,back);splits.push(...F(planes,I(nodes,at)*20,4));return index;};
			const root=partition(I(models,36));sky.partition={root,children:new Int32Array(children),planes:new Float32Array(splits)};
		}
		if (sky) for (let at = 0; at < leaves.byteLength; at += 32) if ((U(leaves, at + 6) & 511) === skyArea) for (let j = 0; j < U(leaves, at + 22); j++) skyFaces.add(U(leafFaces, (U(leaves, at + 20) + j) * 2));
		const inSky = point => this.inSky({sky},point);
		for (const e of entities) e.sky = !!inSky(e.origin);
		const worldspawn = definitions.find(e => e.classname === 'worldspawn') || {}, lightEnvironment = definitions.find(e => e.classname === 'light_environment');
		const hdr = !lump(8).length, color = (normal, high, scale) => { const value = vector(hdr && high && !high.startsWith('-1') ? high : normal, '0 0 0 0'), intensity = (value[3] ?? 255)/255*(hdr ? Number(scale ?? 1) : 1); return value.slice(0,3).map(v => (v/255)**2.2*intensity); };
		library.hdr = hdr;
		const cubemaps = [], cubeSamples = SourceIO.view(lump(42)), cubeSuffix = hdr ? '.hdr' : '', cubeRoot = 'maps/'+name+'/';
		for (let at = 0; at < cubeSamples.byteLength; at += 16) {
			const origin = [0,1,2].map(axis=>I(cubeSamples,at+axis*4)), texture = await library.texture(cubeRoot+'c'+origin.join('_')+cubeSuffix);
			if (texture) cubemaps.push({origin,texture});
		}
		const defaultPath = cubeRoot+'cubemapdefault'+cubeSuffix, cubemapDefault = library.embedded.has('materials/'+defaultPath+'.vtf') ? await library.texture(defaultPath) : null;
		let lighting = null;
		const ambientIndex = lump(hdr ? 51 : 52), ambientSamples = lump(hdr ? 55 : 56);
		if (ambientIndex.length && ambientSamples.length) {
			lighting = {root:I(models,36), planes:new Float32Array(planes.byteLength/20*4), nodes:new Int32Array(nodes.byteLength/32*3), bounds:new Int16Array(leaves.byteLength/32*6), index:new Uint16Array(ambientIndex.slice().buffer), samples:ambientSamples.slice()};
			for (let n = 0; n*20 < planes.byteLength; n++) lighting.planes.set(F(planes,n*20,4),n*4);
			for (let n = 0; n*32 < nodes.byteLength; n++) for (let k = 0; k < 3; k++) lighting.nodes[n*3+k] = I(nodes,n*32+k*4);
			for (let n = 0; n*32 < leaves.byteLength; n++) for (let k = 0; k < 6; k++) lighting.bounds[n*6+k] = leaves.getInt16(n*32+8+k*2,true);
			lighting.contents = new Int32Array(leaves.byteLength/32); for (let n = 0; n < lighting.contents.length; n++) lighting.contents[n] = I(leaves,n*32);
			// dworldlight_t (L4D2: 100 bytes, adds shadow_cast_offset): the same lights VRAD baked into
			// the lightmaps; the engine lights dynamic models with them on top of the leaf ambient cube.
			const lights = SourceIO.view(lump(hdr ? 54 : 15)); lighting.lights = [];
			for (let at = 0; at + 100 <= lights.byteLength; at += 100) {
				const v = F(lights, at, 12), type = I(lights, at + 52), w = F(lights, at + 60, 7);
				lighting.lights.push({origin:v.slice(0,3), intensity:v.slice(3,6), normal:v.slice(6,9), type, stopdot:w[0], stopdot2:w[1], exponent:w[2], radius:w[3], attenuation:w.slice(4,7)});
			}
		}
		if (sky) sky.fog = {'m_fog.enable':Number(skyDefinition.fogenable || 0), 'm_fog.blend':Number(skyDefinition.fogblend || 0), 'm_fog.start':Number(skyDefinition.fogstart || 0), 'm_fog.end':Number(skyDefinition.fogend || 0), 'm_fog.maxdensity':Number(skyDefinition.fogmaxdensity ?? 1), 'm_fog.HDRColorScale':Number(skyDefinition.hdrcolorscale ?? 1), direction:vector(skyDefinition.fogdir), 'm_fog.colorPrimary':vector(skyDefinition.fogcolor).reduce((packed,c,i)=>packed|(c<<(i*8)),0), 'm_fog.colorSecondary':vector(skyDefinition.fogcolor2).reduce((packed,c,i)=>packed|(c<<(i*8)),0)};
		// VRAD's emit_skylight: `normal` is the direction the light travels (SetupLightNormalFromProps:
		// z = sin(pitch), not AngleVectors' -sin), so the sun lies at -normal. Taken from the lump, not
		// re-derived from light_environment's keys (which put the sun on the opposite side).
		const skyLight = lighting?.lights.filter(light => light.type === 3).sort((a, b) => Math.max(...b.intensity) - Math.max(...a.intensity))[0];
		const environment = {sunDirection:skyLight ? Array.from(skyLight.normal, v => -v) : null, skyname:worldspawn.skyname, sunAngles:lightEnvironment ? [Number(lightEnvironment.pitch ?? vector(lightEnvironment.angles)[0]), vector(lightEnvironment.angles)[1], 0] : [0,0,0], sunColor:color(lightEnvironment?._light,lightEnvironment?._lighthdr,lightEnvironment?._lightscalehdr), ambientColor:color(lightEnvironment?._ambient,lightEnvironment?._ambienthdr,lightEnvironment?._ambientscalehdr)};
		if (environment.skyname) environment.skyMaterials = await Promise.all(['rt','lf','bk','ft','up','dn'].map(async suffix => {
			const material = await library.material('skybox/'+environment.skyname+suffix), values = material.values, text = values.$basetexturetransform || '';
			const pair = (key, fallback) => { const match = text.match(new RegExp(key+'\\s+([-+.\\deE]+)\\s+([-+.\\deE]+)','i')); return match ? match.slice(1).map(Number) : fallback; };
			const center = pair('center',[.5,.5]), scale = pair('scale',[1,1]), translate = pair('translate',[0,0]), angle = Number(text.match(/rotate\s+([-+.\deE]+)/i)?.[1] || 0)*Math.PI/180, c = Math.cos(angle), s = Math.sin(angle);
			return {texture:material.texture, encoding:values.$hdrcompressedtexture ? 2 : material.texture?.float ? 1 : 0, color:vector((values.$color || '1 1 1').replace(/[\[\]{}]/g,'')).map(v=>v*(material.texture?.format===25 ? 16 : 1)/(values.$color?.includes('{') ? 255 : 1)), transform:[c*scale[0],-s*scale[1],center[0]+translate[0]-c*scale[0]*center[0]+s*scale[1]*center[1],s*scale[0],c*scale[1],center[1]+translate[1]-s*scale[0]*center[0]-c*scale[1]*center[1]]};
		}));
		const first = I(models, 40), count = I(models, 44), groups = new Map(), brushModels = {}, lightmaps = []; let displacements = 0;
		let lightPage = null, lightX = 0, lightY = 0, lightRow = 0;
		// RGBExp32 stays packed; the fragment shader decodes neighbours before interpolation.
		const allocateLight = (offset, width, height) => {
			if (offset < 0 || !light.length) return null;
			if (lightX + width + 2 > 1024) { lightX = 0; lightY += lightRow; lightRow = 0; }
			if (!lightPage || lightY + height + 2 > 1024) { lightPage = {width:1024, height:1024, data:new Uint8Array(1024*1024*4), flags:12, noMipmap:true}; lightmaps.push(lightPage); lightX = lightY = lightRow = 0; }
			const x = lightX + 1, y = lightY + 1;
			for (let row = -1; row <= height; row++) for (let col = -1; col <= width; col++) {
				const at = offset + (Math.max(0,Math.min(height-1,row))*width+Math.max(0,Math.min(width-1,col)))*4;
				lightPage.data.set(light.subarray(at,at+4),((y+row)*1024+x+col)*4);
			}
			lightX += width + 2; lightRow = Math.max(lightRow,height+2); return {page:lightmaps.length-1, x, y};
		};
		const owners = new Int32Array(face.byteLength / 56); owners.fill(-1); owners.fill(0, first, first + count);
		for (let n = 1; n * 48 < models.byteLength; n++) owners.fill(n, I(models, n * 48 + 40), I(models, n * 48 + 40) + I(models, n * 48 + 44));
		for (let index = 0; index < owners.length; index++) {
			const owner = owners[index]; if (owner < 0) continue;
			const fp = index * 56, start = I(face, fp + 4), length = U(face, fp + 8), ti = face.getInt16(fp + 10, true), di = face.getInt16(fp + 12, true);
			if (length < 3 || ti < 0) continue; const tp = ti * 72, flags = I(tex, tp + 64); if (flags & (6 | 0x40 | 0x80 | 0x100 | 0x200)) continue;
			const texture = I(tex, tp + 68) * 32, path = SourceIO.string(names, I(table, I(td, texture + 12) * 4));
			const width = Math.max(1, I(td, texture + 16)), height = Math.max(1, I(td, texture + 20)), s = F(tex, tp, 4), t = F(tex, tp + 16, 4), ls = F(tex, tp + 32, 4), lt = F(tex, tp + 48, 4), normal = F(planes, U(face, fp) * 20, 3).map(n => face.getUint8(fp + 2) ? -n : n);
			const poly = []; for (let j = 0; j < length; j++) { const e = I(surf, (start + j) * 4); poly.push(F(vert, U(edge, Math.abs(e) * 4 + (e >= 0 ? 0 : 2)) * 12, 3)); }
			const dot = (a, p) => a[0] * p[0] + a[1] * p[1] + a[2] * p[2] + a[3], lightOffset = I(face, fp + 20), lx = I(face, fp + 28), ly = I(face, fp + 32), lw = I(face, fp + 36) + 1, lh = I(face, fp + 40) + 1;
			const lightRegion = allocateLight(lightOffset,lw,lh);
			function lighting(u, v) { return lightRegion ? [lightRegion.x+Math.max(0,Math.min(lw-1,u)),lightRegion.y+Math.max(0,Math.min(lh-1,v)),0] : [1,1,1]; }
			const isSky = owner === 0 && skyFaces.has(index), key = owner + '|' + Number(isSky) + '|' + path + '|' + (lightRegion?.page ?? -1);
			if (!groups.has(key)) groups.set(key, {path, owner, sky:isSky, lightmap:lightRegion ? lightmaps[lightRegion.page] : null, vertices:[]}); const out = groups.get(key).vertices;
			function emit(p, alpha = 0, baked = lighting(dot(ls,p)-lx, dot(lt,p)-ly)) { const position = isSky ? p.map((v, k) => (v - sky.origin[k]) * sky.scale) : p; out.push(...position, ...normal, dot(s, p) / width, dot(t, p) / height, ...baked, alpha); }
			if (di >= 0 && length === 4) {
				const at = di * 176, origin = F(disp, at, 3), n = 2 ** I(disp, at + 20) + 1, startVertex = I(disp, at + 12), grid = [], lightGrid = [], alpha = [];
				let nearest = 0; for (let j = 1; j < 4; j++) if (Math.hypot(...poly[j].map((v, k) => v - origin[k])) < Math.hypot(...poly[nearest].map((v, k) => v - origin[k]))) nearest = j;
				const corners = [...poly.slice(nearest), ...poly.slice(0, nearest)];
				// Displacement lightmaps run from the start corner along the grid columns and rows.
				for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
					const u = x / (n - 1), v = y / (n - 1), d = F(dv, (startVertex + y * n + x) * 20, 5);
					const flat = [0,1,2].map(k => (1-u)*(1-v)*corners[0][k]+u*(1-v)*corners[3][k]+u*v*corners[2][k]+(1-u)*v*corners[1][k]);
					lightGrid.push(lighting(u*(lw-1), v*(lh-1))); grid.push(flat.map((value,k)=>value+d[k]*d[3]));
					// BSP displacement alpha is a byte-range weight stored as a float. Bound it before interpolation.
					alpha.push(Math.max(0, Math.min(1, d[4] / 255)));
				}
				for (let y = 0; y < n - 1; y++) for (let x = 0; x < n - 1; x++) { const a = y * n + x; for (const j of [a,a+1,a+n+1,a,a+n+1,a+n]) emit(grid[j], alpha[j], lightGrid[j]); } displacements++;
			} else for (let j = 1; j < length - 1; j++) { emit(poly[0]); emit(poly[j]); emit(poly[j+1]); }
		}
		const world = []; let loaded = 0;
		for (const {path, owner, sky:isSky, lightmap, vertices} of groups.values()) {
			library.progress('地图材质 ' + (++loaded) + ' / ' + groups.size);
			const original = await library.material(path), key = '*' + owner;
			// A portal background can mix distant room masks and real window glass on the same brush.
			if (portalWindows[key]) {
				const base = SourceIO.path(original.values.$basetexture || '');
				if (original.shader === 'windowimposter' || original.shader === 'black' || original.name.startsWith('tools/') || base === 'tools/toolsblack' || base === 'effects/black') continue;
			}
			const material = {...original, twoSided:true, sky:isSky, brush:true, lightmap}, group = {vertices:new Float32Array(vertices), material};
			if (owner) (brushModels[key] ||= []).push(group); else world.push(group);
		}
		const props = [], game = SourceIO.view(lump(35));
		if (game.byteLength) for (let n = 0; n < I(game, 0); n++) {
			const at = 4 + n * 16; if (game.getUint32(at, true) !== 0x73707270) continue;
			const version = U(game, at + 6), offset = I(game, at + 8), size = I(game, at + 12), modelNames = [], total = I(b, offset);
			for (let j = 0; j < total; j++) modelNames.push(SourceIO.string(bytes, offset + 4 + j * 128));
			let p = offset + 4 + total * 128; const propLeaves = p + 4; p += 4 + I(b, p) * 2; const num = I(b, p); p += 4; if (!num) continue; const stride = (offset + size - p) / num;
			if (version < 4 || stride < 56 || !Number.isInteger(stride)) throw Error('静态道具格式不支持：' + version);
			for (let j = 0; j < num; j++) {
				const row = p + j * stride, origin = F(b, row, 3); let isSky = !!inSky(origin);
				if (sky) for (let k = 0; k < U(b, row + 28); k++) if ((U(leaves, U(b, propLeaves + (U(b, row + 26) + k) * 2) * 32 + 6) & 511) === skyArea) isSky = true;
				const lightingFile = library.embedded.get('sp_'+(hdr ? 'hdr_' : '')+j+'.vhv'), vertexLighting = lightingFile ? this.vertexLighting(await lightingFile()) : null;
				props.push({model:SourceIO.path(modelNames[U(b, row + 24)]), origin:isSky ? origin.map((v, k) => (v - sky.origin[k]) * sky.scale) : origin, angles:F(b, row + 12, 3), skin:I(b, row + 32), body:0, scale:isSky ? sky.scale : 1, sky:isSky, lightingOrigin:bytes[row+31]&2 ? F(b,row+44,3) : origin, vertexLighting});
			}
		}
		const navBytes = await library.read('maps/' + name + '.nav'); if (!navBytes) library.warnings.add('地图没有 NAV，道路高度图不可用');
		const nav = this.nav(navBytes);
		return {map:name, world, props, entities, brushModels, portalWindows, sky, environment, lighting, cubemaps, cubemapDefault, layers:{nav}, counts:{world:world.reduce((n, g) => n + g.vertices.length / 36, 0), nav:nav.length / 9, props:props.length}, displacements};
	}
};
