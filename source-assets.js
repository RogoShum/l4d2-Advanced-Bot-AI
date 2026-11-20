'use strict';
// Source binary resources, read through a browser handle or the local viewer service.
globalThis.SourceDirectory = class {
	constructor(service, path, name, listings = new Map()) { this.service = service; this.path = path; this.name = name; this.kind = 'directory'; this.listings = listings; }
	async list() {
		if (!this.listings.has(this.path)) this.listings.set(this.path, (async () => {
			const response = await fetch(this.service + '/api/game-directory?path=' + encodeURIComponent(this.path));
			if (!response.ok) throw new DOMException('无法读取游戏目录：' + this.path, response.status === 404 ? 'NotFoundError' : 'NotAllowedError');
			return new Map((await response.json()).map(entry => [entry.name.toLowerCase(), entry]));
		})());
		return this.listings.get(this.path);
	}
	async getDirectoryHandle(name) {
		const entry = (await this.list()).get(name.toLowerCase());
		if (!entry) throw new DOMException(name, 'NotFoundError');
		if (entry.kind !== 'directory') throw new DOMException(name, 'TypeMismatchError');
		return new SourceDirectory(this.service, this.path + '/' + entry.name, entry.name, this.listings);
	}
	async getFileHandle(name) {
		const entry = (await this.list()).get(name.toLowerCase());
		if (!entry) throw new DOMException(name, 'NotFoundError');
		if (entry.kind !== 'file') throw new DOMException(name, 'TypeMismatchError');
		const url = this.service + '/api/game-file?path=' + encodeURIComponent(this.path + '/' + entry.name), size = entry.size;
		const read = async (start, end) => {
			if (start >= end) return new ArrayBuffer(0);
			const response = await fetch(url, {headers:{Range:'bytes=' + start + '-' + (end - 1)}});
			if (!response.ok) throw Error('无法读取游戏文件：' + entry.name + ' (' + response.status + ')');
			return response.arrayBuffer();
		};
		const offset = value => Math.max(0, Math.min(size, value < 0 ? size + value : value));
		return {kind:'file', name:entry.name, getFile:async () => ({size, slice:(start = 0, end = size) => ({arrayBuffer:() => read(offset(start), offset(end))}), arrayBuffer:() => read(0, size), text:async () => new TextDecoder().decode(await read(0, size))})};
	}
	async *entries() { for (const entry of (await this.list()).values()) yield [entry.name, {kind:entry.kind}]; }
};
globalThis.SourceIO = {
	path(value) {
		const parts = [];
		for (const part of value.replace(/\\/g, '/').toLowerCase().split('/')) {
			if (!part || part === '.') continue;
			if (part === '..') { if (!parts.length) throw Error('资源路径越界：' + value); parts.pop(); }
			else parts.push(part);
		}
		return parts.join('/');
	},
	view: bytes => new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength),
	text: bytes => new TextDecoder().decode(bytes),
	string(bytes, offset) { let end = offset; while (end < bytes.length && bytes[end]) end++; return this.text(bytes.subarray(offset, end)); },
	half(value) { const sign = value & 32768 ? -1 : 1, exponent = value>>10&31, mantissa = value&1023; return sign*(exponent ? 2**(exponent-15)*(1+mantissa/1024) : mantissa*2**-24); },
	floats(view, offset, count) { return Array.from({length: count}, (_, i) => view.getFloat32(offset + i * 4, true)); },
	keys(text) {
		const tokens = text.replace(/\/\/[^\n\r]*/g, '').match(/"(?:\\.|[^"\\])*"|[{}]|[^\s{}"]+/g) || []; let i = 0;
		const word = () => tokens[i++].replace(/^"|"$/g, '');
		function object() { const out = {}; while (i < tokens.length && tokens[i] !== '}') { const key = word().toLowerCase(); if (tokens[i] === '{') { i++; out[key] = object(); } else if (i < tokens.length) out[key] = word(); } i++; return out; }
		const shader = word().toLowerCase(); if (tokens[i++] !== '{') return {shader, values: {}}; return {shader, values: object()};
	}
};

globalThis.SourceAssets = class {
	constructor(root, progress = () => {}) { this.root = root; this.progress = progress; this.sources = []; this.embedded = new Map(); this.files = new Map(); this.materials = new Map(); this.textures = new Map(); this.models = new Map(); this.animations = new Map(); this.warnings = new Set(); }
	async file(path) {
		path = SourceIO.path(path);
		if (!this.files.has(path)) this.files.set(path, (async () => {
			try { const parts = path.split('/'); let dir = this.root; for (const part of parts.slice(0, -1)) dir = await dir.getDirectoryHandle(part); return await (await dir.getFileHandle(parts.at(-1))).getFile(); }
			catch (e) { if (e.name === 'NotFoundError' || e.name === 'TypeMismatchError') return null; throw e; }
		})());
		return this.files.get(path);
	}
	async directory(path) { let dir = this.root; try { for (const part of path.split('/')) dir = await dir.getDirectoryHandle(part); return dir; } catch (e) { if (e.name === 'NotFoundError') return null; throw e; } }
	async mount() {
		if (!await this.directory('left4dead2')) throw Error('请选择包含 left4dead2 文件夹的游戏根目录');
		const folders = ['update', 'left4dead2_dlc3', 'left4dead2_dlc2', 'left4dead2_dlc1', 'left4dead2', 'hl2'];
		const listFile = await this.file('left4dead2/addonlist.txt');
		const enabled = listFile ? Object.entries(SourceIO.keys(await listFile.text()).values).filter(([, value]) => value === '1').map(([name]) => SourceIO.path(name)).sort() : [];
		for (const name of enabled) {
			const path = 'left4dead2/addons/' + name;
			if (name.endsWith('.vpk') && !/_\d{3}\.vpk$/.test(name)) await this.vpk(path);
			else if (await this.directory(path)) this.sources.push({folder:path});
		}
		for (const folder of folders) {
			const dir = await this.directory(folder); if (!dir) continue;
			this.sources.push({folder});
			const paths = []; for await (const [name, handle] of dir.entries()) if (handle.kind === 'file' && name.endsWith('_dir.vpk')) paths.push(folder + '/' + name);
			for (const path of paths.sort()) await this.vpk(path);
		}
		this.progress('已关联 ' + this.root.name + ' · ' + this.sources.filter(source => source.entries).length + ' 个资源包'); return this;
	}
	async vpk(path) {
		const file = await this.file(path); if (!file) return;
		const header = SourceIO.view(new Uint8Array(await file.slice(0, 28).arrayBuffer())), version = header.getUint32(4, true), size = header.getUint32(8, true), start = version === 1 ? 12 : 28;
		if (header.getUint32(0, true) !== 0x55aa1234 || ![1, 2].includes(version)) throw Error('VPK 格式不支持：' + path);
		const bytes = new Uint8Array(await file.slice(start, start + size).arrayBuffer()), view = SourceIO.view(bytes), entries = new Map(); let p = 0;
		const string = () => { const result = SourceIO.string(bytes, p); p += result.length + 1; return result; };
		for (let ext; (ext = string());) for (let dir; (dir = string());) for (let name; (name = string());) {
			const preload = view.getUint16(p + 4, true), archive = view.getUint16(p + 6, true), offset = view.getUint32(p + 8, true), length = view.getUint32(p + 12, true);
			if (view.getUint16(p + 16, true) !== 65535) throw Error('VPK 目录损坏：' + path); p += 18;
			entries.set(SourceIO.path((dir === ' ' ? '' : dir + '/') + name + '.' + ext), {archive, offset, length, preload: bytes.slice(p, p + preload)}); p += preload;
		}
		this.sources.push({path, file, start: start + size, entries});
	}
	async read(path) { const t0=performance.now(); try { return await this.readInner(path); } finally { const p=(globalThis.__perf||(globalThis.__perf={})); p.read=(p.read||0)+performance.now()-t0; p.reads=(p.reads||0)+1; } }
	async readInner(path) {
		path = SourceIO.path(path); if (this.embedded.has(path)) return this.embedded.get(path)();
		// Search each directory and its packs together; a lower-priority loose file must not override update/.
		for (const pack of this.sources) {
			if (pack.folder) { const file = await this.file(pack.folder + '/' + path); if (file) return new Uint8Array(await file.arrayBuffer()); continue; }
			const e = pack.entries.get(path); if (!e) continue;
			const file = e.archive === 0x7fff ? pack.file : await this.file(pack.path.replace('_dir.vpk', '_' + String(e.archive).padStart(3, '0') + '.vpk'));
			if (!file) throw Error('缺少 VPK 分卷：' + pack.path + ' / ' + e.archive);
			const offset = e.offset + (e.archive === 0x7fff ? pack.start : 0), result = new Uint8Array(e.preload.length + e.length);
			result.set(e.preload); result.set(new Uint8Array(await file.slice(offset, offset + e.length).arrayBuffer()), e.preload.length); return result;
		}
		return null;
	}
	zip(bytes) {
		const v = SourceIO.view(bytes); let end = bytes.length - 22;
		while (end >= Math.max(0, bytes.length - 65558) && v.getUint32(end, true) !== 0x06054b50) end--;
		if (end < 0) return; let p = v.getUint32(end + 16, true);
		for (let i = 0; i < v.getUint16(end + 10, true); i++) {
			if (v.getUint32(p, true) !== 0x02014b50) throw Error('BSP 内嵌资源目录损坏');
			const method = v.getUint16(p + 10, true), length = v.getUint32(p + 20, true), n = v.getUint16(p + 28, true), local = v.getUint32(p + 42, true);
			const path = SourceIO.path(SourceIO.text(bytes.subarray(p + 46, p + 46 + n))), start = local + 30 + v.getUint16(local + 26, true) + v.getUint16(local + 28, true);
			this.embedded.set(path, async () => { const data = bytes.subarray(start, start + length); if (method === 0) return data; if (method !== 8) throw Error('ZIP 压缩方式不支持：' + method); return new Uint8Array(await new Response(new Blob([data]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer()); });
			p += 46 + n + v.getUint16(p + 30, true) + v.getUint16(p + 32, true);
		}
	}
	async materialDefinition(path, parents = []) {
		path = SourceIO.path(path).replace(/^materials\//, '').replace(/\.vmt$/, '');
		if (parents.includes(path)) throw Error('材质循环引用：' + path);
		const bytes = await this.read('materials/' + path + '.vmt');
		if (!bytes) { this.warnings.add('缺少材质 ' + path); return {shader:'', values:{}}; }
		let {shader, values} = SourceIO.keys(SourceIO.text(bytes));
		if (shader === 'patch' && values.include) { const base = await this.materialDefinition(values.include, [...parents, path]); shader = base.shader; values = {...base.values, ...values.insert, ...values.replace}; }
		if ((shader === 'sky' || shader === 'sky_hdr_dx9') && (values.$hdrcompressedtexture || values.$hdrbasetexture)) values = {...values, ...values.sky_hdr_dx9};
		return {shader, values};
	}
	async material(path) {
		path = SourceIO.path(path).replace(/^materials\//, '').replace(/\.vmt$/, '');
		if (!this.materials.has(path)) this.materials.set(path, (async () => {
			const {shader, values} = await this.materialDefinition(path);
			const enabled=value=>value==='1'||String(value).toLowerCase()==='true',visible=shader!=='nodraw'&&!['$no_draw','%compilenodraw','%compileinvisible','%compilehint','%compileskip','%compilesky','%compile2dsky','%compiletrigger','%compileorigin','%compilefog','%compileclip','%playerclip','%compileplayerclip','%compilenpcclip','%compiledroneclip','%compilegrenadeclip'].some(key=>enabled(values[key]));
			const sky = shader === 'sky' || shader.startsWith('sky_'), texturePath = sky ? values.$hdrcompressedtexture || values.$hdrbasetexture || values.$basetexture : values.$basetexture;
			const texture = texturePath ? await this.texture(texturePath) : null;
			const mask = values.$selfillummask ? await this.texture(values.$selfillummask) : null;
			const emissive = values.$emissiveblendtexture ? await this.texture(values.$emissiveblendtexture) : null;
			const second = values.$basetexture2 ? await this.texture(values.$basetexture2) : null;
			const gradient = shader === 'infected' && values.$disablevariation !== '1' && values.$gradienttexture ? await this.texture(values.$gradienttexture) : null;
			// Characters also get normal and specular-exponent maps for the realistic shading path.
			const character = !!values.$bumpmap || values.$phong === '1';
			const normalPath = shader === 'water' ? values.$normalmap : values.$bumpmap;
			const normal = (character || shader === 'water') && normalPath ? await this.texture(normalPath) : null;
			const flow = shader === 'water' && values.$flowmap ? await this.texture(values.$flowmap) : null;
			const exponent = character && values.$phongexponenttexture ? await this.texture(values.$phongexponenttexture) : null;
			const lightwarp = values.$lightwarptexture ? await this.texture(values.$lightwarptexture) : null;
			// EyeRefract / Eyes: the iris is projected from the MDL eyeball, not taken from the mesh UVs.
			const iris = /eye/.test(shader) && values.$iris ? await this.texture(values.$iris) : null;
			const envmapPath = values.$envmap && values.$envmap !== 'env_cubemap' ? SourceIO.path(values.$envmap).replace(/^materials\//, '').replace(/\.vtf$/, '') : null;
			const envmap = envmapPath ? await this.texture(envmapPath + (this.hdr && this.embedded.has('materials/'+envmapPath+'.hdr.vtf') ? '.hdr' : '')) : null;
			const envmapMask = values.$envmapmask ? await this.texture(values.$envmapmask) : null;
			const alphaByTeam = values.proxies?.playerteam ? [0,1,2,3].map(team => {
				const variables = {...values, $alpha:Number(values.$alpha ?? 1)}, scalar = name => Number(variables[String(name).toLowerCase()] ?? name);
				for (const [name, proxy] of Object.entries(values.proxies)) {
					let value;
					if (name === 'playerteam') value = team !== 0 && team === Number(proxy.team) ? 1 : 0;
					else if (name === 'subtract') value = scalar(proxy.srcvar1)-scalar(proxy.srcvar2);
					else if (name === 'multiply') value = scalar(proxy.srcvar1)*scalar(proxy.srcvar2);
					else continue;
					variables[proxy.resultvar.toLowerCase()] = value;
				}
				return variables.$alpha;
			}) : null;
			return {name: path, shader, values, visible, texture, mask, emissive, second, gradient, normal, exponent, lightwarp, flow, envmap, envmapMask, alphaByTeam, iris};
		})()); return this.materials.get(path);
	}
	async hudIcons(manifest, viewmodels) {
		const scripts = new Set(), wantedModels = new Set(manifest.models.map(model=>model.path)), wantedClasses = new Set(manifest.entities.map(entity=>entity.classname));
		const noticeWeapons = new Set(manifest.events.filter(e=>e.name==='player_death' || e.name==='player_incapacitated').map(e=>(e.weapon || '').replace(/^weapon_/,'')));
		const weaponScript = path => /^scripts\/(?:weapon_[^/]+|melee\/[^/]+)\.txt$/.test(path);
		for (const path of this.embedded.keys()) if (weaponScript(path)) scripts.add(path);
		for (const source of this.sources) {
			if (source.entries) { for (const path of source.entries.keys()) if (weaponScript(path)) scripts.add(path); continue; }
			for (const folder of ['scripts','scripts/melee']) {
				const directory = await this.directory(source.folder+'/'+folder); if (!directory) continue;
				for await (const [name, entry] of directory.entries()) { const path=SourceIO.path(folder+'/'+name); if (entry.kind==='file' && weaponScript(path)) scripts.add(path); }
			}
		}
		const definitions = new Map(), requests = new Map(), result = {};
		const request = async (definition, keys) => {
			if (!definition?.file || !keys.length) return;
			const path=SourceIO.path(definition.file);
			if (!definitions.has(path)) definitions.set(path,await this.materialDefinition(path));
			const texture=definitions.get(path).values.$basetexture; if (!texture) return;
			const key=SourceIO.path(texture).replace(/^materials\//,'').replace(/\.vtf$/,'');
			if (!requests.has(key)) requests.set(key,[]);
			requests.get(key).push({definition,keys});
		};
		for (const path of [...scripts].sort()) {
			const bytes=await this.read(path); if (!bytes) continue;
			const values=SourceIO.keys(SourceIO.text(bytes)).values, classname=path.slice(path.lastIndexOf('/')+1,-4), melee=path.startsWith('scripts/melee/'), textures=values.texturedata;
			if (values.viewmodel) {
				const info={path:SourceIO.path(values.viewmodel), arms:values.characterviewmodeladdon || null};
				if (!melee) viewmodels[classname]=info;
				if(melee)for (const key of ['worldmodel','playermodel','addonmodel']) if (values[key]) viewmodels[SourceIO.path(values[key])]=info;
				if(values.viewmodel_dual) for(const key of ['playermodel_dual','worldmodel_dual']) if(values[key]) viewmodels[SourceIO.path(values[key])]={...info,path:SourceIO.path(values.viewmodel_dual)};
			}
			if (!textures) continue;
			const models=['playermodel','worldmodel','addonmodel','viewmodel'].flatMap(key=>values[key] ? [SourceIO.path(values[key])] : []), keys=models.filter(model=>wantedModels.has(model));
			if (!melee && classname!=='weapon_melee' && wantedClasses.has(classname)) keys.push(classname);
			if (noticeWeapons.has(classname.replace(/^weapon_/,''))) keys.push('notice:'+classname.replace(/^weapon_/,''));
			await request(melee ? textures.sprite_active : textures.weapon || textures.weapon_s,keys);
			const dual=['playermodel_dual','worldmodel_dual','viewmodel_dual'].flatMap(key=>values[key] ? [SourceIO.path(values[key])] : []).filter(model=>wantedModels.has(model));
			if (classname==='weapon_pistol' && noticeWeapons.has('dual_pistols')) dual.push('notice:dual_pistols');
			await request(textures.weapon_dual,dual);
		}
		const attacks={tank_claw:'tip_tank_incap',smoker_claw:'tip_smoker_swipe',hunter_claw:'tip_hunter_swipe',jockey_claw:'tip_jockey_swipe',spitter_claw:'tip_spitter_claw',boomer_claw:'tip_boomer_swipe'};
		if (Object.keys(attacks).some(key=>noticeWeapons.has(key))) {
			const bytes=await this.read('scripts/mod_textures.txt'), icons=bytes && SourceIO.keys(SourceIO.text(bytes)).values.texturedata;
			for (const [weapon,key] of Object.entries(attacks)) if (noticeWeapons.has(weapon)) await request(icons?.[key],['notice:'+weapon]);
		}
		for (const [path, entries] of requests) {
			const bytes=await this.read('materials/'+path+'.vtf'); if (!bytes) { this.warnings.add('缺少 HUD 纹理 '+path); continue; }
			let atlas; try { atlas=SourceTexture.decode(bytes,0,false,false,Infinity); } catch(error) { this.warnings.add(path+': '+error.message); continue; }
			const crops=new Map();
			for (const {definition,keys} of entries) {
				const x=Number(definition.x || 0),y=Number(definition.y || 0),width=Number(definition.width),height=Number(definition.height),key=[x,y,width,height].join(',');
				if (![x,y,width,height].every(Number.isInteger) || width<1 || height<1 || x<0 || y<0 || x+width>atlas.width || y+height>atlas.height) { this.warnings.add('HUD 图标区域无效 '+path); continue; }
				if (!crops.has(key)) {
					const rgba=new Uint8Array(width*height*4);
					for (let row=0;row<height;row++) {
						const pixels=atlas.data.subarray(((y+row)*atlas.width+x)*4,((y+row)*atlas.width+x+width)*4);
						if (atlas.float) for(let i=0;i<pixels.length;i++)rgba[row*width*4+i]=Math.round(Math.max(0,Math.min(1,i%4===3 ? pixels[i] : pixels[i]**(1/2.2)))*255);
						else rgba.set(pixels,row*width*4);
					}
					crops.set(key,{width,height,rgba});
				}
				for (const name of keys) result[name]=crops.get(key);
			}
		}
		return result;
	}
	async texture(path) {
		path = SourceIO.path(path).replace(/^materials\//, '').replace(/\.vtf$/, '');
		if (!this.textures.has(path)) this.textures.set(path, (async () => { const bytes = await this.read('materials/' + path + '.vtf'); if (!bytes) { this.warnings.add('缺少纹理 ' + path); return null; } try { const t0=performance.now(); const decoded=SourceTexture.decode(bytes); (globalThis.__perf||(globalThis.__perf={})).decode=(globalThis.__perf.decode||0)+performance.now()-t0; globalThis.__perf.decodePixels=(globalThis.__perf.decodePixels||0)+(decoded.faces || [decoded]).reduce((sum,image)=>sum+image.width*image.height,0); return decoded; } catch (error) { this.warnings.add(path + ': ' + error.message); return null; } })());
		return this.textures.get(path);
	}
	model(path) { path = SourceIO.path(path); if (!this.models.has(path)) this.models.set(path, SourceModel.load(this, path)); return this.models.get(path); }
};
globalThis.SourceTexture = {
	compressed: false,
	size(format, w, h) { if ([13, 20].includes(format)) return Math.ceil(w / 4) * Math.ceil(h / 4) * 8; if ([14, 15].includes(format)) return Math.ceil(w / 4) * Math.ceil(h / 4) * 16; const bpp = {0:4,1:4,2:3,3:3,4:2,5:1,6:2,8:1,11:4,12:4,16:4,19:2,21:2,24:8,25:8}[format]; if (!bpp) throw Error('不支持的 VTF 像素格式 ' + format); return w * h * bpp; },
	sheet(bytes, offset) {
		const d=SourceIO.view(bytes);let p=offset+4;const int=()=>{const value=d.getUint32(p,true);p+=4;return value;},float=()=>{const value=d.getFloat32(p,true);p+=4;return value;},version=int();if(version>1)throw Error('不支持的VTF粒子图集版本：'+version);const result=[];
		for(let n=int();n>0;n--){const id=int(),loop=!!int(),count=int(),duration=float(),frames=[];for(let i=0;i<count;i++){const frame={duration:float(),bounds:[]};for(let j=0;j<(version?4:1);j++)frame.bounds.push(Array.from({length:4},float));frames.push(frame);}result.push({id,loop,duration,frames});}return result;
	},
	decode(bytes, frame = 0, keepAnimation = true, compressed = this.compressed, maxDimension = 1024, face = null) {
		const v = SourceIO.view(bytes); if (SourceIO.string(bytes, 0) !== 'VTF') throw Error('VTF 文件头错误');
		const minor = v.getUint32(8, true), width = v.getUint16(16, true), height = v.getUint16(18, true), flags = v.getUint32(20, true), frames = v.getUint16(24, true), format = v.getInt32(52, true), mips = bytes[56], depth = minor >= 2 ? Math.max(1, v.getUint16(63, true)) : 1;
		let offset = v.getUint32(12, true); if (bytes[61] && bytes[62]) offset += this.size(v.getInt32(57, true), bytes[61], bytes[62]);
		if (minor >= 3) for (let i = 0; i < v.getUint32(68, true); i++) if ((v.getUint32(80 + i * 8, true) & 0xffffff) === 0x30) offset = v.getUint32(84 + i * 8, true);
		let sheet=null;if(minor>=3)for(let i=0;i<v.getUint32(68,true);i++)if((v.getUint32(80+i*8,true)&0xffffff)===0x10)sheet=this.sheet(bytes,v.getUint32(84+i*8,true));
		const faces = flags & 0x4000 ? (minor < 5 && v.getUint16(26, true) !== 65535 ? 7 : 6) : 1;
		if (faces > 1 && face === null) return {faces:Array.from({length:6}, (_, i) => this.decode(bytes, frame, false, compressed, maxDimension, i)), flags, format};
		const image = frame*faces+(face ?? 0);
		let level = 0; while (level + 1 < mips && Math.max(width >> level, height >> level) > maxDimension) level++;
		// S3TC data goes to the GPU as stored (block decode in JS was ~8 s of a c1m4 load):
		// The selected frame and cube face, slice 0, from the chosen mip level down.
		const dxt = {13:'dxt1', 20:'dxt1', 14:'dxt3', 15:'dxt5'}[format];
		if (compressed && dxt && (width >> level) % 4 === 0 && (height >> level) % 4 === 0) {
			const starts = []; let at = offset;
			for (let mip = mips - 1; mip >= 0; mip--) { starts[mip] = at; at += this.size(format, Math.max(1, width >> mip), Math.max(1, height >> mip)) * frames * faces * Math.max(1, depth >> mip); }
			const levels = [];
			for (let mip = level; mip < mips; mip++) { const w = Math.max(1, width >> mip), h = Math.max(1, height >> mip), size = this.size(format, w, h); if ((w % 4 && w > 2) || (h % 4 && h > 2)) break; if (starts[mip] + size > bytes.length) break; levels.push({width:w, height:h, data:bytes.slice(starts[mip] + image*size*Math.max(1,depth>>mip), starts[mip] + (image*Math.max(1,depth>>mip)+1)*size)}); }
			if (levels.length) return {width:levels[0].width, height:levels[0].height, compressed:dxt, levels, flags, frames, sheet, source:frames>1 && keepAnimation ? bytes : null, sourceWidth:width, sourceHeight:height, format};
		}
		for (let mip = mips - 1; mip > level; mip--) offset += this.size(format, Math.max(1, width >> mip), Math.max(1, height >> mip)) * frames * faces * Math.max(1, depth >> mip);
		const w = Math.max(1, width >> level), h = Math.max(1, height >> level), out = new Uint8Array(w * h * 4), data = bytes.subarray(offset + image*this.size(format,w,h)*Math.max(1,depth>>level), offset + (image*Math.max(1,depth>>level)+1)*this.size(format,w,h)), d = SourceIO.view(data);
		if (format === 24 || format === 25) {
			const pixels = new Float32Array(w*h*4);
			for (let i=0;i<pixels.length;i++) {
				const n=d.getUint16(i*2,true);
				// Negative and non-finite FP16 cubemap texels contaminate the filtered reflection and its mip chain.
				if (format===24 && faces>1 && n>=0x7c00) continue;
				pixels[i]=format===24 ? SourceIO.half(n) : n/65535;
			}
			return {width:w,height:h,data:pixels,float:true,flags,frames,sheet,source:frames>1 && keepAnimation ? bytes : null,sourceWidth:width,sourceHeight:height,format};
		}
		const rgb565 = x => [Math.round((x >> 11) * 255 / 31), Math.round(((x >> 5) & 63) * 255 / 63), Math.round((x & 31) * 255 / 31), 255];
		if ([13, 14, 15, 20].includes(format)) {
			let p = 0; for (let y = 0; y < h; y += 4) for (let x = 0; x < w; x += 4) {
				const color = p + ([14, 15].includes(format) ? 8 : 0), a = d.getUint16(color, true), b = d.getUint16(color + 2, true), palette = [rgb565(a), rgb565(b)];
				if (a > b || [14, 15].includes(format)) { palette.push(palette[0].map((n, i) => (n * 2 + palette[1][i]) / 3)); palette.push(palette[0].map((n, i) => (n + palette[1][i] * 2) / 3)); }
				else { palette.push(palette[0].map((n, i) => (n + palette[1][i]) / 2)); palette.push([0, 0, 0, 0]); }
				const codes = d.getUint32(color + 4, true), alpha = [data[p], data[p + 1]];
				if (format === 15) { if (alpha[0] > alpha[1]) for (let j = 1; j <= 6; j++) alpha.push(((7 - j) * alpha[0] + j * alpha[1]) / 7); else { for (let j = 1; j <= 4; j++) alpha.push(((5 - j) * alpha[0] + j * alpha[1]) / 5); alpha.push(0, 255); } }
				for (let j = 0; j < 16; j++) { if (x + j % 4 >= w || y + (j >> 2) >= h) continue; const c = palette[(codes >>> (j * 2)) & 3].slice(); if (format === 14) c[3] = ((data[p + (j >> 1)] >> ((j & 1) * 4)) & 15) * 17; if (format === 15) { const bit = j * 3, k = p + 2 + (bit >> 3); c[3] = alpha[((data[k] | ((data[k + 1] || 0) << 8)) >> (bit & 7)) & 7]; } out.set(c, ((y + (j >> 2)) * w + x + j % 4) * 4); }
				p += [13, 20].includes(format) ? 8 : 16;
			}
		} else {
			const stride = this.size(format, 1, 1); for (let i = 0; i < w * h; i++) { const p = i * stride; let c;
				if (format === 0) c = Array.from(data.subarray(p, p + 4));
				else if (format === 1) c = [data[p + 3], data[p + 2], data[p + 1], data[p]];
				else if (format === 2) c = [data[p], data[p + 1], data[p + 2], 255];
				else if (format === 3) c = [data[p + 2], data[p + 1], data[p], 255];
				else if (format === 5 || format === 6) c = [data[p], data[p], data[p], format === 6 ? data[p + 1] : 255];
				else if (format === 8) c = [255, 255, 255, data[p]];
				else if (format === 11) c = [data[p + 1], data[p + 2], data[p + 3], data[p]];
				else if (format === 12 || format === 16) c = [data[p + 2], data[p + 1], data[p], format === 12 ? data[p + 3] : 255];
				else if (format === 4) c = rgb565(d.getUint16(p, true));
				else throw Error('未实现 VTF 像素转换 ' + format);
				out.set(c, i * 4);
			}
		}
		return {width:w, height:h, data:out, flags, frames, sheet, source:frames>1 && keepAnimation ? bytes : null, sourceWidth:width, sourceHeight:height, format};
	}
};
