'use strict';

globalThis.ReplayLoader = class {
	constructor(progress) {
		const object = value => '{' + Object.entries(value).map(([name, fn]) => {
			const source = fn.toString();
			return /^(?:async\s+)?\*?\w+\s*\(/.test(source) ? source : JSON.stringify(name) + ':' + source;
		}).join(',') + '}';
		const geometry = {prepareWorld:ReplayRenderer.prepareWorld, transform:ReplayRenderer.transform, point:ReplayRenderer.point, modelMaterial:ReplayRenderer.modelMaterial, transparent:ReplayRenderer.prototype.transparent};
		const definitions = [
			'SourceIO=' + object(SourceIO), 'SourceDirectory=' + SourceDirectory.toString(), 'SourceFileList=' + SourceFileList.toString(), 'SourceAssets=' + SourceAssets.toString(),
			'SourceTexture=' + object(SourceTexture), 'SourceAnimation=' + object(SourceAnimation), 'SourcePhysics=' + object(SourcePhysics),
			'SourceSprite=' + object(SourceSprite), 'SourceParticles=' + object(SourceParticles), 'SourceModel=' + object(SourceModel),
			'ReplayFrameCodec=' + ReplayFrameCodec.toString(), 'ReplayZstd=' + ReplayZstd.toString(),
			'SourceMap=' + object(SourceMap), 'ReplayRenderer=' + object(geometry), 'ReplayChunks=' + ReplayChunks.toString()
		].map(source => 'const ' + source + ';').join('\n');
		const url = URL.createObjectURL(new Blob([definitions, '\n(', replayWorker.toString(), ')();'], {type:'text/javascript'}));
		this.worker = new Worker(url); URL.revokeObjectURL(url); this.pending = new Map(); this.sequence = 0;
		this.worker.onmessage = ({data}) => {
			if (data.progress !== undefined) { progress(data.progress); return; }
			const pending = this.pending.get(data.request); if (!pending) return; this.pending.delete(data.request);
			if (data.error) { pending.reject(Error(data.error)); return; }
			if (pending.type === 'load') {
				for (const key of ['trails', 'spriteTrails']) for (const [id, points] of Object.entries(data.result.manifest.timeline[key])) data.result.manifest.timeline[key][id] = new Float32Array(points);
				data.result.recording = new ReplayRecording(this, data.result.id, data.result.manifest); delete data.result.manifest;
			}
			pending.resolve(data.result);
		};
		this.worker.onerror = event => { for (const pending of this.pending.values()) pending.reject(Error(event.message)); this.pending.clear(); };
	}
	request(type, data = {}) {
		if (data.source?.url) data = {...data, source:{...data.source,url:new URL(data.source.url, location.href).href}};
		return new Promise((resolve, reject) => { const request = ++this.sequence; this.pending.set(request, {type, resolve, reject}); this.worker.postMessage({type, request, ...data}); });
	}
	dispose() { this.worker.terminate(); for (const pending of this.pending.values()) pending.reject(Error('播放器已关闭')); this.pending.clear(); }
};

function replayWorker() {
	const progress = text => postMessage({progress:text}), recordings = new Map(); let mounted, serial = 0, queue = Promise.resolve();
	function transfers(value, buffers = new Set(), seen = new Set()) {
		if (!value || typeof value !== 'object' || seen.has(value)) return buffers; seen.add(value);
		if (value instanceof ArrayBuffer) buffers.add(value);
		else if (ArrayBuffer.isView(value)) buffers.add(value.buffer);
		else for (const child of Object.values(value)) transfers(child, buffers, seen);
		return buffers;
	}
	function brushModels(map, models) {
		for (const [path, entries] of Object.entries(map.brushModels)) {
			const materials = entries.map(group => group.material), groups = entries.map((entry, materialIndex) => {
				const data = entry.vertices, count = data.length / 12, vertices = new Float32Array(count * 3), normals = new Float32Array(count * 3), uv = new Float32Array(count * 2), lighting = new Float32Array(count * 3), weights = new Float32Array(count * 3), indices = Uint32Array.from({length:count}, (_, i) => i);
				for (let i = 0; i < count; i++) { vertices.set(data.subarray(i * 12, i * 12 + 3), i * 3); normals.set(data.subarray(i * 12 + 3, i * 12 + 6), i * 3); uv.set(data.subarray(i * 12 + 6, i * 12 + 8), i * 2); lighting.set(data.subarray(i * 12 + 8, i * 12 + 11), i * 3); weights[i * 3] = 1; }
				for (let i = 0; i < count; i += 3) { const offset = i * 3, ax = vertices[offset + 3] - vertices[offset], ay = vertices[offset + 4] - vertices[offset + 1], az = vertices[offset + 5] - vertices[offset + 2], bx = vertices[offset + 6] - vertices[offset], by = vertices[offset + 7] - vertices[offset + 1], bz = vertices[offset + 8] - vertices[offset + 2]; if ((ay * bz - az * by) * normals[offset] + (az * bx - ax * bz) * normals[offset + 1] + (ax * by - ay * bx) * normals[offset + 2] < 0) [indices[i + 1], indices[i + 2]] = [indices[i + 2], indices[i + 1]]; }
				return {vertices, normals, uv, lighting, weights, indices, bones:new Uint16Array(count * 3), materialIndex, lod:0};
			});
			models[path] = {path, groups, materials, skins:[], replacements:{}, used:[0], bones:[], attachments:[]};
		}
		delete map.brushModels;
	}
	function describeModel(model) {
		// Source virtualmodel include order determines the merged pose parameter ranges.
		const poseParameters = [], byName = new Map(), visit = (animation, seen = new Set()) => {
			if (!animation || seen.has(animation)) return; seen.add(animation);
			for (const pose of animation.poseParameters || []) { const key = pose.name.toLowerCase(), current = byName.get(key); if (!current) { const copy = {name:pose.name, start:pose.start, end:pose.end, loop:pose.loop}; byName.set(key, copy); poseParameters.push(copy); } else { const low = Math.min(current.start, current.end, pose.start, pose.end), high = Math.max(current.start, current.end, pose.start, pose.end); current.start = low; current.end = high; } }
			for (const child of animation.includes || []) visit(child, seen);
		};
		visit(model.animation);
		return {bones:model.bones.map(bone => ({name:bone.name, parent:bone.parent, flags:bone.flags})), hitboxBones:model.bones.filter(bone => bone.flags & 256).map(bone => bone.id), hitboxSets:model.hitboxSets || [], poseParameters, ...(model.collision ? {collision:{solids:model.collision.solids, bodies:model.collision.bodies}} : {})};
	}
	async function load(source, chapter) {
		progress('读取录像索引…');
		const recording = new ReplayChunks(source), manifest = await recording.open(chapter), library = new SourceAssets(mounted.root, progress);
		library.sources = mounted.sources; library.files = mounted.files;
		for (const model of manifest.models) model.path = SourceIO.path(model.path);
		const map = await SourceMap.load(library, manifest.map), dynamic = new Set(manifest.models.map(model => model.path)), paths = new Set([...dynamic, ...map.props.map(prop => prop.model)]), models = {};
		const pending = [...paths].filter(path => path && !path.startsWith('*')); let complete = 0;
		await Promise.all(Array.from({length:3}, async () => {
			while (pending.length) { const path = pending.shift(); models[path] = await library.model(path); progress('模型与材质 ' + (++complete) + ' / ' + paths.size); }
		}));
		// The recording stores model paths. Rigging and collision come from the mounted game.
		for (const descriptor of manifest.models) if (descriptor.path.endsWith('.mdl') && models[descriptor.path]?.bones) Object.assign(descriptor, describeModel(models[descriptor.path]));
		brushModels(map, models);
		[map.flashlight, map.flashlightGlow] = await Promise.all([library.texture('effects/flashlight001'), library.material('particle/flashlight_glow')]);
		map.viewmodels = {}; map.hudIcons = await library.hudIcons(manifest,map.viewmodels);
		map.particles = await SourceParticles.load(library, [...new Set([...(manifest.particleEffects || []), 'molotov_groundfire', 'burning_character'])], manifest.map);
		progress('准备地图…'); map.world = ReplayRenderer.prepareWorld(map, models);
		for (const path of Object.keys(models)) if (!dynamic.has(path)) delete models[path];
		const materials = new Map(); let serialMesh = 0;
		recording.drawModels = manifest.models.map(({path}) => {
			const model = models[path]; if (!model) return null;
			return model.groups.map((group, mesh) => {
				const geometry = ++serialMesh, byMaterial = new Map();
				const command = skin => {
					const m = ReplayRenderer.modelMaterial(model, group, skin); if (m?.visible === false) return null;
					if (!materials.has(m)) materials.set(m, materials.size);
					if (!byMaterial.has(m)) byMaterial.set(m, {mesh, geometry, material:materials.get(m), blend:ReplayRenderer.transparent(m) || Object.values(m?.alphaByTeam || {}).some(v => v > 0 && v < 1)});
					return byMaterial.get(m);
				};
				return {base:group.base, variants:group.variants, variant:group.variant, skins:Array.from({length:model.skins.length}, (_,skin)=>command(skin)), defaultSkin:command(-1)};
			});
		});
		const id = ++serial; recordings.set(id, recording);
		return {id, manifest, chapters:recording.chapters, G:map, models, warnings:[...library.warnings]};
	}
	let fileLibrary = null;
	onmessage = ({data}) => {
		// Single files for the viewer (sounds, scripts): answered at once, not queued behind seeks.
		if (['file','viewMesh','viewClip'].includes(data.type)) {
			(async () => {
				try {
					if (!mounted) { postMessage({request:data.request, result:null}); return; }
					if (!fileLibrary) { fileLibrary = new SourceAssets(mounted.root, progress); fileLibrary.sources = mounted.sources; fileLibrary.files = mounted.files; }
					if (data.type === 'viewMesh') {
						const {path,groups,used,bones,materials,skins,replacements,animation} = await fileLibrary.model(data.path);
						const actions={}, collect=source=>{for(const seq of source.sequences){const key={ACT_VM_IDLE:'idle',ACT_VM_PRIMARYATTACK:'fire',ACT_VM_HITCENTER:'fire',ACT_VM_DRAW:'draw',ACT_VM_DEPLOY:'draw'}[seq.activity]; if(key && !actions[key])actions[key]=seq.name;}for(const child of source.includes)collect(child);}; collect(animation);
						postMessage({request:data.request,result:{path,groups,used,bones,materials,skins,replacements,actions}}); return;
					}
					if (data.type === 'viewClip') {
						const model=await fileLibrary.model(data.path), arms=data.arms && await fileLibrary.model(data.arms), match=SourceAnimation.find(model.animation,data.layer || data.sequence);
						if (!match) { postMessage({request:data.request,result:null}); return; }
						const {source,sequence}=match, speed=SourceAnimation.cycleRate(source,sequence,SourceAnimation.axes(source,sequence,new Map())), duration=speed>0?1/speed:0;
						const frames=Math.max(2,...sequence.animations.map(id=>source.animations[id]?.frames || 1)), count=model.used.length+(arms?.used.length || 0);
						const muzzleName=sequence.name.includes('left')?'muzzle_flash_l':'muzzle_flash_r', attachment=model.attachments.find(a=>a.name==='muzzle_flash') || model.attachments.find(a=>a.name===muzzleName), local=attachment && SourceModel.rows(attachment.matrix), muzzle=attachment && new Float32Array(frames*6);
						const palette=new Float32Array(frames*count*16), identity=SourceModel.quaternion([0,0,0],[0,0,0,1]), rest=arms && SourceAnimation.sample(arms);
						for(let i=0;i<frames;i++){
							if(i && i%8===0)await new Promise(resolve=>setTimeout(resolve,0));
							const cycle=i/(frames-1), pose=SourceAnimation.sample(model,{sequence:data.sequence,cycle:data.layer?0:cycle,time:cycle*duration,overlays:data.layer?[{sequence:data.layer,cycle,weight:1,order:0}]:[]});
							if(muzzle){const m=SourceModel.multiply(pose.bones[attachment.bone],local);muzzle.set(m.subarray(12,15),i*6);muzzle.set(m.subarray(0,3),i*6+3);}
							let at=i*count*16; for(const id of model.used){palette.set(pose.skin[id],at);at+=16;}
							if(arms){const hand=SourceAnimation.boneMerge(arms,rest,model,pose,identity,identity);for(const id of arms.used){palette.set(hand.skin[id],at);at+=16;}}
						}
						postMessage({request:data.request,result:{palette,muzzle,frames,count,duration,loop:!!(sequence.flags&1)}},muzzle?[palette.buffer,muzzle.buffer]:[palette.buffer]); return;
					}
					const bytes = await fileLibrary.read(data.path), copy = bytes ? bytes.slice() : null;
					postMessage({request:data.request, result:copy}, copy ? [copy.buffer] : []);
				} catch (error) { postMessage({request:data.request, error:error.stack || error.message}); }
			})();
			return;
		}
		queue = queue.then(async () => {
			try {
				let result;
				if (data.type === 'mount') {
					SourceTexture.compressed = !!data.compressed;
					let root = data.root;
					if (root.service) root = new SourceDirectory(root.service, '', root.name);
					else if (root.files) root = new SourceFileList(root.name, root.files);
					mounted = await new SourceAssets(root, progress).mount();
				}
				else if (data.type === 'load') result = await load(data.source,data.chapter);
				else if (data.type === 'seek') result = await recordings.get(data.id).seek(data.time);
				else if (data.type === 'release') { recordings.get(data.id)?.dispose(); recordings.delete(data.id); }
				const transfer = data.type === 'load' ? [...transfers({G:result.G, models:result.models})] : [];
				postMessage({request:data.request, result}, transfer);
			} catch (error) { postMessage({request:data.request, error:error.stack || error.message}); }
		});
	};
}
