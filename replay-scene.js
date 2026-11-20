'use strict';
// Growable pos3+rgba4 vertex stream for per-frame diagnostic lines and glow triangles.
globalThis.ReplayLineBuffer = class {
	constructor() { this.data = new Float32Array(7 * 4096); this.length = 0; }
	reset() { this.length = 0; }
	reserve(count) { if (this.length + count <= this.data.length) return; let size = this.data.length * 2; while (size < this.length + count) size *= 2; const data = new Float32Array(size); data.set(this.data.subarray(0, this.length)); this.data = data; }
	vertex(x, y, z, c) { if (this.length + 7 > this.data.length) this.reserve(7); const d = this.data, i = this.length; d[i] = x; d[i + 1] = y; d[i + 2] = z; d[i + 3] = c[0]; d[i + 4] = c[1]; d[i + 5] = c[2]; d[i + 6] = c[3]; this.length = i + 7; }
	points(points, c) { this.reserve(points.length / 3 * 7); for (let i = 0; i < points.length; i += 3) this.vertex(points[i], points[i + 1], points[i + 2], c); }
	view() { return this.data.subarray(0, this.length); }
};
globalThis.ReplayScene = class {
	constructor(manifest, map, models, renderer, ui, camera, loader) {
		this.viewLoader = loader; this.viewMeshes = new Map(); this.viewClips = new Map();
		this.manifest = manifest; this.map = map; this.models = models; this.renderer = renderer; this.ui = ui; this.camera = camera; this.springs = new Map(); this.ragdolls = new ReplayRagdolls(map); this.deaths = new Map(); this.corpseBounds = new Map(); this.corpsePoses = new Map(); this.corpsePoseBytes = 0;
		this.poseNames = manifest.models.map(model => (model.poseParameters || []).map(parameter => parameter.name));
		this.poseRoots = new Set();
		this.poseBoneIds = manifest.models.map(descriptor => (descriptor.hitboxBones || []).map(id => models[descriptor.path]?.bones.findIndex(bone => bone.name === descriptor.bones[id].name) ?? -1));
		this.overlay = $('overlay'); this.context = this.overlay.getContext('2d'); this.prepareMini();
		this.burning = new Map();
		this.witchTargets = Object.values(manifest.timeline.witchTargets || {});
		this.botai = new ReplayBotAI(manifest, ui, camera); this.lines = new ReplayLineBuffer(); this.glowBuffer = new ReplayLineBuffer(); this.tongueBuffer = new ReplayLineBuffer(); this.lodCache = new Map(); this.collisionCache = new Map(); this.staticCache = new Map();
		// Pose evaluation and ragdoll stepping run in worker threads when available (ReplayJobs).
		try { this.jobs = typeof Worker !== 'undefined' && !globalThis.__replayNoJobs ? new ReplayJobs(map, () => hooks.invalidate()) : null; } catch (error) { console.warn('Replay job workers unavailable:', error); this.jobs = null; }
		this.trails = Object.entries(manifest.timeline.trails).map(([id, points]) => ({id:Number(id), mesh:renderer.trail(id, points, .11, 64, 1.6)}));
	}
	setFrame(frame, seek) {
		this.frame = frame; this.states = frame.prepared.states; this.next = frame.prepared.next; this.owners = frame.prepared.owners;
		this.staticKeys = new Map();
		// Corpses survive a seek: ragdoll steps are fixed, so a body simulated up to some age (or its
		// settled final pose) is valid at any later time; addRagdoll restarts one only when the new
		// time needs frames it already dropped. Newly needed corpses catch up with a larger budget.
		if (seek) { this.catchingUp = true; this.lodCache.clear(); this.springs.clear(); this.burning.clear(); }
		for (const id of this.poseRoots) if (!this.states.has(id)) this.poseRoots.delete(id);
		const live = new Set(frame.entities.map(a => a.id)); for (const id of this.springs.keys()) if (!live.has(id)) this.springs.delete(id); for (const cache of [this.lodCache, this.collisionCache, this.staticCache]) for (const id of cache.keys()) if (!live.has(id)) cache.delete(id);
		this.deaths = new Map(frame.deaths.map(event => [event.id + ':' + event.t, event])); this.deadActors = new Set(frame.deaths.map(event => event.id)); const deathKeys = new Set(this.deaths.keys()); let removed = false;
		for (const key of this.ragdolls.bodies.keys()) if (!deathKeys.has(key)) { this.ragdolls.bodies.delete(key); removed = true; }
	}
	model(state) { const descriptor = this.manifest.models[state.model]; return descriptor ? this.models[descriptor.path] : null; }
	viewAsset(cache,key,type,args) {
		if(!cache.has(key)){
			cache.set(key,null);
			this.viewLoader.request(type,args).then(asset=>{
				if(!this.viewLoader || !asset)return;
				if(type==='viewMesh'){
					if(!this.renderer.models[asset.path])this.renderer.addModels({[asset.path]:asset});
					this.renderer.gl.bindVertexArray(null);this.renderer.meshFor(asset.path);
				}
				cache.set(key,asset); hooks.invalidate();
			}).catch(error=>{if(this.viewLoader)showError(error);});
		}
		return cache.get(key);
	}
	firstPerson(player,time) {
		if(this.camera.mode!=='first' || player?.team!==2 || !this.viewLoader)return null;
		const item=player.inventory?.find(i=>i.active), vm=player.eye?.viewmodel, defs=this.map.viewmodels;
		if(!item)return null;
		const world=this.manifest.models[item.model]?.path, def=defs[world] || defs[item.classname], path=vm?.model || def?.path;
		if(!path)return null;
		const weapon=this.viewAsset(this.viewMeshes,path,'viewMesh',{path});
		if(!weapon || !vm && !weapon.actions.idle)return null;
		const character=this.manifest.models[player.model]?.path.match(/survivor_(\w+)\.mdl$/)?.[1], armsPath=(def?.arms || defs.weapon_pistol?.arms)?.[character];
		const arms=armsPath && this.viewAsset(this.viewMeshes,SourceIO.path(armsPath),'viewMesh',{path:SourceIO.path(armsPath)});
		if(armsPath && !arms)return null;
		const clip=(sequence,layer)=>{
			if(!sequence)return null;
			const key=[path,arms?.path,sequence,layer].join('|');
			return this.viewAsset(this.viewClips,key,'viewClip',{path,arms:arms?.path,sequence,layer});
		};
		const base=vm?.sequence || weapon.actions.idle;
		let selected=clip(base), elapsed=vm?Math.max(0,time-this.frame.sampleTime)*vm.rate:time, cycle=vm?.cycle || 0;
		if(!vm && weapon.actions.fire)clip(weapon.actions.fire);
		if(!vm && weapon.actions.draw)clip(weapon.actions.draw);
		if(!selected)return null;
		if(vm){
			if(vm.rate && !vm.cycle)elapsed=Math.max(0,time-vm.start)*vm.rate;
			const next=this.next.get(player.id)?.eye?.viewmodel, layer=next?.model===vm.model && next.sequence===base && next.layerStart>vm.layerStart && next.layerStart<=time ? next : vm;
			if(layer.layer && layer.layerStart<=time && time-layer.layerStart<10){
				const overlay=clip(base,layer.layer), age=time-layer.layerStart;
				if(overlay && age<overlay.duration){selected=overlay;elapsed=age;cycle=0;}
			}
		}else{
			const fire=this.frame.events.findLast(e=>e.name==='weapon_fire' && e.userid===player.userid && e.t<=time && e.t>=(player.activeSince ?? 0));
			const start=fire?.t ?? player.activeSince, action=fire?weapon.actions.fire:weapon.actions.draw;
			if(action && start!=null && time-start<2){
				const eventClip=clip(action); if(eventClip && time-start<eventClip.duration){selected=eventClip;elapsed=time-start;}
			}
		}
		let phase=cycle+(selected.duration?elapsed/selected.duration:0);phase=selected.loop?phase%1:Math.min(1,phase);
		return {weapon,arms,clip:selected,frame:phase*(selected.frames-1),body:vm?.body || 0,skin:vm?.skin || 0};
	}
	async prepareFrame(frame) {
		const states = new Map(frame.entities.map(s => [s.id,s])), next = new Map(frame.nextEntities.map(s => [s.id,s])), owners = new Map(), poses = new Map();
		for (const state of frame.entities) for (const item of state.inventory || []) owners.set(item.id,state);
		frame.prepared = {states,next,owners,poses,draws:this.renderer.prepareCommands(frame,states,next,owners,this.manifest)};
		if (!this.jobs?.live || !this.renderer.hdr) return frame;
		const trees = new Map(), nodes = new Map();
		const add = s => {
			if (!s || nodes.has(s.id)) return nodes.get(s?.id);
			nodes.set(s.id,null);
			const model = this.model(s); if (!model?.animation || !model.bones.length || !s.origin || !(s.render?.scale > 0) || s.entity===0 || s.render.effects&32 || s.render.mode===10 || !(s.render.color>>>24) || SourceMap.inSky(this.map,s.origin)) return null;
			const target=next.get(s.id);if(target?.model===s.model && target.origin && SourceMap.inSky(this.map,target.origin))return null;
			const owner = owners.get(s.id), item = owner?.inventory.find(i=>i.id===s.id), parentId = owner?.id ?? (s.render.sprite?.attached || s.parent?.id);
			const attachment=s.render.sprite?.attached ? s.render.sprite.attachment : s.parent?.attachment;
			const parentState=states.get(parentId), needsParent=item?.attachment || attachment>0 || s.render.sprite?.attached || s.render.effects&1;
			const parent=needsParent && parentState ? add(parentState) : null;
			if(needsParent && !parent && parentState?.entity && parentState.render && !(parentState.render.effects&32) && parentState.render.mode!==10 && parentState.render.color>>>24 && this.model(parentState))return null;
			const tree = parent?.tree || []; if (!parent) trees.set(s.id,tree);
			const compact = a => a && {model:a.model,origin:a.origin,angles:a.angles,sequence:a.sequence,rate:a.rate,cycle:a.cycle,pose:a.pose,overlays:a.overlays,bones:a.render.bones};
			const node = {id:s.id,path:model.path,parent:parent?.index ?? -1,name:item?.attachment,active:!!item?.active,attachment,sprite:!!s.render.sprite?.attached,merge:!!(s.render.effects&1),scale:s.render.scale,a:compact(s),b:compact(next.get(s.id))};
			tree.push(node); const ref = {tree,index:tree.length-1}; nodes.set(s.id,ref); return ref;
		};
		for (const s of frame.entities) if (s.entity !== 0 && s.render && !(s.render.effects&32) && s.render.mode!==10 && s.render.color>>>24 && !/^weapon_\w+_claw$/.test(s.classname) && (s.kind==='actor' || owners.has(s.id) || s.parent || s.render.sprite?.attached || this.poseRoots.has(s.id))) add(s);
		await this.jobs.bake(frame,trees,this);
		return frame;
	}
	posePair(entry, model, time) {
		const {samples,first,rows,root}=entry, p=clamp((time-this.frame.sampleTime)/(this.frame.nextTime-this.frame.sampleTime || 1),0,1)*(samples.length-1), i=Math.min(Math.floor(p),samples.length-2);
		const a=samples[i],b=samples[i+1],blend=p-i,cache=[]; let inverse;
		// HUD, lighting and effects request individual bones from the same baked inputs, without GPU readback.
		const matrix = row => {
			if (cache[row]) return cache[row];
			const o=row*28,x=a.palette,y=b.palette,mix=k=>x[o+k]+(y[o+k]-x[o+k])*blend;
			const m=SourceModel.quaternion([mix(4),mix(5),mix(6)],SourceAnimation.slerp(x.subarray(o,o+4),y.subarray(o,o+4),blend)), scale=mix(7);
			for(let k=0;k<12;k++)m[k]*=scale;
			const parent=x[o+24];return cache[row]=parent<0?m:SourceModel.multiply(matrix(parent),m);
		};
		return {a,b,blend,first,count:model.used.length,get world(){return matrix(root)},at:id=>rows[id]===undefined?undefined:SourceModel.multiply(inverse ||= SourceModel.inverse(matrix(root)),matrix(first+rows[id])),skinAt:slot=>SourceModel.multiply(matrix(first+slot),model.bones[model.used[slot]].bindInverse ||= SourceModel.rows(model.bones[model.used[slot]].inverse))};
	}
	interpolated(state, time) {
		const next = this.next.get(state.id), blend = next && next.model === state.model && this.frame.nextTime > this.frame.sampleTime ? clamp((time - this.frame.sampleTime) / (this.frame.nextTime - this.frame.sampleTime), 0, 1) : 0;
		return ReplayScene.interpolateState(state,next,blend,this.frame.nextTime-this.frame.sampleTime,this.model(state)?.animation);
	}
	static interpolateState(state,next,blend,gap,animation) {
		if (!blend) return state;
		const result = {...state, origin:state.origin.map((v, i) => v + (next.origin[i] - v) * blend), angles:state.angles.map((v, i) => v + ((next.angles[i] - v + 540) % 360 - 180) * blend)};
		// A looping cycle advances by whole loops the samples cannot show: over a recording gap (capture
		// samples dropped, 3.2 s in ab23 at 14:27) the run cycle went 0.84 -> 0.92 and everyone slid with
		// frozen legs. Pick the loop count closest to what the sequence's duration and rate predict.
		const cycle = (sequence, a, b, rate = 1) => {
			const looping = animation && (SourceAnimation.find(animation, sequence)?.sequence.flags & 1); let delta = b - a;
			if (looping) { const duration = sequence.duration > 0 ? sequence.duration : 0, expected = duration ? gap * Math.abs(rate ?? 1) / duration : 0; delta += Math.round(expected - delta); }
			const value = a + delta * blend; return looping ? (value % 1 + 1) % 1 : clamp(value, 0, 1);
		};
		if (state.sequence && next.sequence?.index === state.sequence.index) result.cycle = cycle(state.sequence, state.cycle, next.cycle, state.rate);
		if (state.pose && next.pose) result.pose = state.pose.map((v, i) => v + ((next.pose[i] ?? v) - v) * blend);
		result.overlays = state.overlays?.map(layer => { if (!layer.sequence) return layer; const other = next.overlays?.find(other => other.order === layer.order && other.sequence?.index === layer.sequence.index); return other ? {...layer, cycle:cycle(layer.sequence, layer.cycle, other.cycle), weight:layer.weight + (other.weight - layer.weight) * blend} : layer; });
		return result;
	}
	instance(id, time) {
		if (this.instances.has(id)) return this.instances.get(id);
		const source = this.states.get(id); if (!source) return null;
		const previous = this.previousInstances?.get(id); if (previous !== undefined) { this.instances.set(id, previous); return previous; }
		if (source.entity === 0 || source.render.effects & 32 || source.render.mode === 10 || (source.render.color >>> 24) === 0) return null;
		// Infected claws (weapon_hunter_claw, weapon_tank_claw ...) are weapons without a world model;
		// their m_iWorldModelIndex falls back to the default pistol, which the game never draws.
		if (/^weapon_\w+_claw$/.test(source.classname)) return null;
		const baked=this.frame.prepared.poses.get(id);
		if (baked) {
			const model=this.model(source), pair=this.posePair(baked,model,time), instance={state:source,model,descriptor:this.manifest.models[source.model],get nativeWorld(){return pair.world},get world(){return pair.world},sky:false,pose:{at:pair.at},posePair:pair};
			this.instances.set(id,instance);return instance;
		}
		const lod = this.lodStep(source);
		// A null key is also valid for the whole sample: this entity still needs interpolation.
		let staticKey = this.staticKeys.get(id);
		if (staticKey === undefined) { staticKey = this.staticKey(source); this.staticKeys.set(id, staticKey); }
		if (staticKey) { const hit = this.staticCache.get(id); if (hit && hit.key === staticKey) { this.instances.set(id, hit.instance); return hit.instance; } }
		const state = this.interpolated(source, time), model = this.model(state); if (!model) return null;
		const descriptor = this.manifest.models[state.model], animationState = {...state, time:this.manifest.clock ? this.manifest.clock.time + time : undefined, poseNames:this.poseNames[state.model], poseParameters:descriptor.poseParameters};
		let world = ReplayRenderer.transform(state.origin, state.angles), sky = SourceMap.inSky(this.map, state.origin);
		if (model.path.startsWith('*')) { const nativeWorld = world; if (sky) world = SourceMap.skyTransform(this.map, world); const instance = {state, model, descriptor, nativeWorld, world, sky, matrices:world, pose:{bones:[]}}; this.instances.set(id, instance); return instance; }
		const parentId = this.owners.get(id)?.id ?? (state.render?.sprite?.attached || state.parent?.id);
		if (parentId == null && !sky && model.animation && !staticKey) this.poseRoots.add(id);
		if (lod) { const cached = this.lodCache.get(id); if (cached && cached.model === source.model && cached.sample === this.frame.sampleTime && Math.abs(time - cached.time) < lod) { const reused = this.reuseInstance(cached, source, time); this.instances.set(id, reused); return reused; } }
		let pose = SourceAnimation.sample(model, animationState);
		const instance = {state, model, nativeWorld:world, world, sky, pose, descriptor}; this.instances.set(id, instance);
		const owner = this.owners.get(id), attachmentState = state.render?.sprite?.attached ? {id:state.render.sprite.attached, attachment:state.render.sprite.attachment} : state.parent, parent = this.instance(owner?.id ?? attachmentState?.id, time);
		if (parent) {
			const inventory = owner?.inventory.find(item => item.id === id), name = inventory?.attachment, attachment = name ? parent.model.attachments.find(a => a.name === name) : attachmentState?.attachment > 0 ? parent.model.attachments[attachmentState.attachment - 1] : null;
			const bone = name ? parent.model.bones.find(b => b.name === name || b.name === 'ValveBiped.' + name) : null;
			if (attachment) { world = SourceModel.multiply(SourceModel.multiply(parent.nativeWorld, SourceAnimation.boneAt(parent.pose,attachment.bone)), SourceModel.rows(attachment.matrix)); sky = parent.sky; }
			else if (bone) { world = SourceModel.multiply(parent.nativeWorld, SourceAnimation.boneAt(parent.pose,bone.id)); sky = parent.sky; }
			else if (state.render?.sprite?.attached) { world = parent.nativeWorld.slice(); sky = parent.sky; }
			if (inventory?.active) { const grip = model.bones.find(b => b.name === 'ValveBiped.weapon_bone'); if (grip && (attachment || bone)) world = SourceModel.multiply(world, SourceModel.inverse(pose.bones[grip.id])); }
		}
		if (state.render && state.render.scale !== 1) for (let k = 0; k < 12; k++) world[k] *= state.render.scale;
		instance.hitboxWorld = []; pose = this.recordedPose(source, model, pose, world, time, instance.hitboxWorld);
		let springs = this.springs.get(id); if (!springs) { springs = new Map(); this.springs.set(id, springs); }
		pose = SourceAnimation.procedural(model, pose, world, time, springs);
		if (parent && (state.render.effects & 1)) pose = SourceAnimation.boneMerge(model, pose, parent.model, parent.pose, parent.nativeWorld, world);
		const nativeWorld = world; if (sky) world = SourceMap.skyTransform(this.map, world);
		const matrices = new Float32Array(model.used.length * 16); for (let k = 0; k < model.used.length; k++) SourceModel.multiply(world, pose.skin[model.used[k]], matrices, k * 16);
		Object.assign(instance, {nativeWorld, world, sky, pose, matrices});
		if (lod) this.lodCache.set(id, {model:source.model, sample:this.frame.sampleTime, time, origin:state.origin.slice(), instance});
		if (staticKey) this.staticCache.set(id, {key:staticKey, instance});
		return instance;
	}
	// Props, pickups and brushes mostly stand still: when nothing that drives their pose changes
	// between this sample and the next, the previous frame's skinning matrices are reused.
	staticKey(source) {
		if (source.kind === 'actor' || source.parent || source.render.sprite?.attached || source.render.beam || source.render.trail || source.overlays?.length || this.owners.has(source.id)) return null;
		const model = this.model(source); if (!model || model.animation?.autoplay?.length) return null;
		if (model._jiggle === undefined) model._jiggle = model.bones.some(bone => bone.proc === 5);
		if (model._jiggle) return null;
		const next = this.next.get(source.id), same = (a, b) => a === b || !!a && !!b && a[0] === b[0] && a[1] === b[1] && a[2] === b[2];
		if (next && (next.model !== source.model || !same(next.origin, source.origin) || !same(next.angles, source.angles) || next.cycle !== source.cycle || next.sequence?.index !== source.sequence?.index)) return null;
		const bones = source.render.bones; if (bones && next) { const other = next.render.bones; if (!other || other.length !== bones.length) return null; for (let i = 0; i < bones.length; i++) if (bones[i] !== other[i]) return null; }
		return source.model + '|' + source.origin + '|' + source.angles + '|' + (source.sequence?.index ?? '') + '|' + source.cycle + '|' + source.pose + '|' + source.body + '|' + source.skin + '|' + source.render.scale + '|' + source.render.effects + '|' + (bones || '');
	}
	outsideEntity(state, planes, box) {
		if (!state.origin || SourceMap.inSky(this.map, state.origin)) return false;
		const mins = state.hull.mins, maxs = state.hull.maxs;
		const hullRadius = Math.hypot(Math.max(-mins[0], maxs[0]), Math.max(-mins[1], maxs[1]), Math.max(-mins[2], maxs[2]));
		// A studio sequence can move the rendered mesh far outside its collision hull.
		const radius = Math.max(hullRadius, (this.model(state)?.animation?.renderRadius || 0) * Math.abs(state.render.scale ?? 1)) + 160;
		if (!(radius < 4000)) return false;
		const next = this.next.get(state.id), end = next && next.model === state.model && next.origin ? next.origin : state.origin;
		for (let k = 0; k < 3; k++) { box[k] = Math.min(state.origin[k], end[k]) - radius; box[k + 3] = Math.max(state.origin[k], end[k]) + radius; }
		return !ReplayRenderer.visible(planes, box);
	}
	// Distant common infected: re-sample animation at most every 0.1-0.2 s of replay time
	// and translate the cached skinning matrices with the body in between (far, small on screen).
	lodStep(state) {
		if (!this.lodEye || !state.origin || this.camera.follow === state.id || state.kind !== 'actor' && state.classname !== 'infected') return 0;
		const dx = state.origin[0] - this.lodEye[0], dy = state.origin[1] - this.lodEye[1], dz = state.origin[2] - this.lodEye[2], d2 = dx * dx + dy * dy + dz * dz;
		// Per-actor jitter spreads the re-samples over frames instead of all on one.
		const jitter = .8 + (Math.imul(state.id, 2654435761) >>> 0) % 1000 / 2500;
		// Survivors and specials keep full rate a bit further out than commons.
		const near = state.classname === 'infected' ? 1 : 1.6;
		return (d2 > (2600 * near) ** 2 ? .2 : d2 > (1400 * near) ** 2 ? .1 : d2 > (650 * near) ** 2 ? .05 : 0) * jitter;
	}
	reuseInstance(cached, source, time) {
		const base = cached.instance, next = this.next.get(source.id), blend = next && next.model === source.model && this.frame.nextTime > this.frame.sampleTime ? clamp((time - this.frame.sampleTime) / (this.frame.nextTime - this.frame.sampleTime), 0, 1) : 0;
		const origin = blend ? source.origin.map((v, i) => v + (next.origin[i] - v) * blend) : source.origin, dx = origin[0] - cached.origin[0], dy = origin[1] - cached.origin[1], dz = origin[2] - cached.origin[2];
		const shift = matrix => { const out = matrix.slice(); for (let k = 12; k < out.length; k += 16) { out[k] += dx; out[k + 1] += dy; out[k + 2] += dz; } return out; };
		const scale = base.sky ? this.map.sky.scale : 1, sdx = dx * scale, sdy = dy * scale, sdz = dz * scale, matrices = base.matrices.slice();
		for (let k = 12; k < matrices.length; k += 16) { matrices[k] += sdx; matrices[k + 1] += sdy; matrices[k + 2] += sdz; }
		const world = base.world.slice(); world[12] += sdx; world[13] += sdy; world[14] += sdz;
		return {...base, state:{...base.state, origin}, nativeWorld:shift(base.nativeWorld), world, matrices, hitboxWorld:null};
	}
	recordedPose(state, model, pose, world, time, hitboxWorld) {
		const descriptor = this.manifest.models[state.model];
		// A local model that differs from the recorded one (e.g. a mod, or a published recording
		// rebuilt from the visitor's files) has another hitbox list: keep the animated pose.
		if (!state.render.bones || state.render.bones.length !== descriptor.hitboxBones.length * 6) return pose;
		const inverse = SourceModel.inverse(world), overrides = [];
		for (let slot = 0; slot < descriptor.hitboxBones.length; slot++) { const id = this.poseBoneIds[state.model][slot]; if (id < 0) continue; const bone = this.hitboxBone(state, descriptor, descriptor.hitboxBones[slot], time); if (hitboxWorld) hitboxWorld[descriptor.hitboxBones[slot]] = bone; overrides[id] = SourceModel.multiply(inverse, bone); }
		return SourceAnimation.overrideBones(model, pose, overrides);
	}
	// defibrillator_used.subject / survivor_rescued.victim / player_spawn.userid are raw userids.
	revivedAfter(event, time) {
		const list = this.reviveEvents || (this.reviveEvents = this.manifest.events.filter(e => /^(defibrillator_used|survivor_rescued|player_spawn)$/.test(e.name || '')));
		const userid = this.states.get(event.id)?.userid ?? event.state.userid; if (userid == null) return false;
		return list.some(e => e.t > event.t + .5 && e.t <= time && (e.name === 'defibrillator_used' ? e.subject === userid : e.name === 'survivor_rescued' ? e.victim === userid : e.userid === userid && this.states.get(event.id)?.life === 0));
	}
	addRagdoll(event, actors, time) {
		const state = event.state, model = this.model(state); if (!model) return;
		const key = event.id + ':' + event.t, age = time - event.t, cached = this.corpsePoses.get(key);
		// Settled fast path: the final pose holds from the age it settled at.
		if (cached && age >= cached.settledAge) { this.corpsePoses.delete(key); this.corpsePoses.set(key, cached); actors.push(event.fade < 1 ? {...cached, alpha:event.fade} : cached); return; }
		if (this.jobs?.live) {
			// The ragdoll worker owns the bodies (same fixed-step code, so seek and play agree); the body's
			// start pose and impulse are computed here once and sent with the first request.
			if (!this.jobs.ragdollWorker.busy) {
				const request = {key, age};
				if (!this.jobs.corpseSent.has(key)) {
					const root = ReplayRenderer.transform(state.origin, state.angles); for (let k = 0; k < 12; k++) root[k] *= state.render.scale;
					const pose = this.recordedPose(state, model, SourceAnimation.sample(model, {...state, time:this.manifest.clock ? this.manifest.clock.time + event.t : undefined, poseNames:this.poseNames[state.model], poseParameters:this.manifest.models[state.model].poseParameters}), root);
					request.create = {path:model.path, world:pose.bones.map(bone => SourceModel.multiply(root, bone)), velocities:model.bones.map(() => state.velocity.slice()), impacts:ReplayScene.deathImpulse(event, this.ui.actorById.get(event.id)?.type)}; this.jobs.corpseSent.add(key);
				}
				this.jobs.queueCorpse(request, model);
			}
			const done = this.jobs.corpses.get(key); if (!done) { this.ragdolls.pending = this.corpseWait = true; return; }
			if (done.bounds) this.corpseBounds.set(key, done.bounds);
			const exact = !done.behind && Math.abs(done.age - age) < 1e-4; if (!exact) this.ragdolls.pending = this.corpseWait = true;
			const actor = {path:model.path, matrices:done.matrices, body:state.body, skin:state.skin, rim:[0, 0, 0, 0], corpse:key}; actors.push(event.fade < 1 ? {...actor, alpha:event.fade} : actor);
			if (exact && done.settledAge != null && age >= done.settledAge) {
				actor.settledAge = done.settledAge; if (cached) { this.corpsePoseBytes -= cached.matrices.byteLength; this.corpsePoses.delete(key); }
				while (this.corpsePoseBytes + actor.matrices.byteLength > 16 * 1024 * 1024 && this.corpsePoses.size) { const first = this.corpsePoses.keys().next().value; this.corpsePoseBytes -= this.corpsePoses.get(first).matrices.byteLength; this.corpsePoses.delete(first); }
				this.corpsePoses.set(key, actor); this.corpsePoseBytes += actor.matrices.byteLength;
			}
			return;
		}
		let body = this.ragdolls.bodies.get(key);
		// Only the last 121 frames are kept: an earlier time (seek backwards) restarts from the death.
		if (body && Math.floor(Math.max(0, age) * 60) < body.frameStart) { this.ragdolls.bodies.delete(key); body = undefined; }
		if (body === undefined) {
			// Creating a body is cheap; it is not gated by the step budget, so every corpse shows at once.
			while (this.ragdolls.bodies.size >= 64) this.ragdolls.bodies.delete(this.ragdolls.bodies.keys().next().value);
			const root = ReplayRenderer.transform(state.origin, state.angles); for (let k = 0; k < 12; k++) root[k] *= state.render.scale;
			const pose = this.recordedPose(state, model, SourceAnimation.sample(model, {...state, time:this.manifest.clock ? this.manifest.clock.time + event.t : undefined, poseNames:this.poseNames[state.model], poseParameters:this.manifest.models[state.model].poseParameters}), root), world = pose.bones.map(bone => SourceModel.multiply(root, bone)), velocities = world.map(() => state.velocity.slice());
			body = this.ragdolls.create(key, model, world, velocities, ReplayScene.deathImpulse(event, this.ui.actorById.get(event.id)?.type));
		} else { this.ragdolls.bodies.delete(key); this.ragdolls.bodies.set(key, body); }
		if (body) {
			const matrices = this.ragdolls.pose(body, age); if (body.bounds) this.corpseBounds.set(key, body.bounds); if (!matrices) return;
			const actor = {path:model.path, matrices, body:state.body, skin:state.skin, rim:[0, 0, 0, 0], corpse:key}; actors.push(event.fade < 1 ? {...actor, alpha:event.fade} : actor);
			if (body.settled && age >= (body.frameCount - 1) / 60) {
				this.ragdolls.bodies.delete(key); actor.settledAge = (body.frameCount - 1) / 60;
				if (cached) { this.corpsePoseBytes -= cached.matrices.byteLength; this.corpsePoses.delete(key); }
				while (this.corpsePoseBytes + matrices.byteLength > 16 * 1024 * 1024 && this.corpsePoses.size) { const first = this.corpsePoses.keys().next().value; this.corpsePoseBytes -= this.corpsePoses.get(first).matrices.byteLength; this.corpsePoses.delete(first); }
				this.corpsePoses.set(key, actor); this.corpsePoseBytes += matrices.byteLength;
			}
		}
	}
	render(time) {
		if (this.camera.mode === 'first') this.camera.updateEye(this.frame, time);
		const canvas = $('world'), view = this.camera.view(canvas.width / canvas.height), eye = this.camera.eye(), actors = [], labels = [], groundRings = [], hitLines = this.lines, glow = this.glowBuffer, active = {}, viewPlanes = ReplayRenderer.planes(view), box = [0, 0, 0, 0, 0, 0];
		hitLines.reset(); glow.reset(); this.tongueBuffer.reset(); this.lodEye = eye; this.culled = 0; const playing = !!window.__viewer?.playing?.(); this.corpseWait = false;
		// Off-screen bodies need no animation, skinning or draw calls. The margin keeps
		// shadows cast into view by bodies just outside it.
		const outside = (state, margin, planes = viewPlanes) => { if (!state.origin || SourceMap.inSky(this.map, state.origin)) return false; const mins = state.hull?.mins || [-24, -24, 0], maxs = state.hull?.maxs || [24, 24, 72]; for (let k = 0; k < 3; k++) { box[k] = state.origin[k] + mins[k] - margin; box[k + 3] = state.origin[k] + maxs[k] + margin; } return !ReplayRenderer.visible(planes, box); };
		// Same replay time and frame (paused, camera moving): every pose is unchanged, so last frame's
		// instances are reused instead of re-sampling animation, bones and skinning matrices.
		this.previousInstances = this.instanceTime === time && this.instanceFrame === this.frame ? this.instances : null; this.instanceTime = time; this.instanceFrame = this.frame;
		this.instances = new Map();
		const flashlights = this.flashlights(time);
		this.ragdolls.pending = false;
		// entityflame deals damage at 0.2 s intervals, including on actors whose networked flags omit FL_ONFIRE.
		for (const hit of this.frame.flameHits) {
			if (hit.t > time || time - hit.t > 1.5) continue;
			const id = hit.actor ?? hit.id, burn = this.burning.get(id);
			if (!burn || hit.t > burn.last + .45) this.burning.set(id, {start:hit.t, last:hit.t});
			else burn.last = Math.max(burn.last, hit.t);
		}
		for (const state of this.frame.entities) {
			const type = actorType(state), actor = state.kind === 'actor', survivor = state.team === 2, meta = this.ui.actorById.get(state.id), color = actorColor(state, meta), rgb = replayRgb(color), followed = this.camera.follow === state.id;
			if (actor && state.life === 0 && (state.flags & (1 << 27))) {
				if (!this.burning.has(state.id)) this.burning.set(state.id, {start:this.frame.sampleTime, last:time});
				this.burning.get(state.id).last = time;
			}
			if (actor && (state.life === 1 || state.life === 2) && this.deadActors.has(state.id)) continue;
			if (state.life === 4) continue;
			if (state.classname === 'survivor_death_model') continue;
			// Map-placed prop_ragdolls (c8m5's dead police) spawn in the model's standing bind pose and the
			// server's physics drops them during the first ~1.5 s, while players are still loading. Their
			// recorded bones are not settled before that, so they are not drawn until then.
			if (state.classname === 'prop_ragdoll' && time - state.start < 2) continue;
			const liveActor = actor && state.life === 0 && (survivor || state.classname === 'infected' || state.classname === 'witch' || state.team === 3 && (specialTypes.includes(type) || type === 'tank'));
			if (liveActor || type === 'tank_rock' || state.volume) active[type] = (active[type] || 0) + 1;
			if (this.camera.mode === 'first' && (followed || this.owners.get(state.id)?.id === this.camera.follow || state.parent?.id === this.camera.follow)) continue;
			if (prefs.hitbox && state.volume) this.volumeLines(hitLines, state, [...rgb, .85]);
			// A door or actor outside the camera can still block a teammate's flashlight.
			if (!actor && state.hull && !state.parent && !state.volume && !state.render.beam && !state.render.trail && !state.render.sprite && !this.owners.has(state.id) && this.outsideEntity(state, viewPlanes, box) && flashlights.every(light => this.outsideEntity(state, light.planes, box))) { this.culled++; continue; }
			if (state.ability?.mouth && state.ability.tip && state.ability.state > 0) this.drawTongue(state, time, eye);
			if (actor && !survivor && !followed && outside(state, 160) && flashlights.every(light => outside(state, 160, light.planes))) { this.culled++; continue; }
			const instance = this.instance(state.id, time);
			if (instance) {
				const biled = actor && ReplayThrowables.isBiled(state, this.frame, time);
				const rim = biled ? [.72, 1, .2, 1.35] : survivor ? [...rgb, followed ? 1.25 : .9] : type === 'tank' ? [1, .22, .28, .95] : type === 'infected' ? [.9, .45, .42, .22] : [...rgb, actor ? .7 : .12];
				const outline = (type === 'tank' || type === 'infected') && state.life === 0 && time - (this.burning.get(state.id)?.last ?? -Infinity) <= .45 ? ReplayScene.fireOutline : biled ? rim : null;
				const sprite = state.render.sprite ? {...state.render.sprite, frame:state.render.sprite.frame + (time - this.frame.sampleTime) * state.render.sprite.rate} : null;
				if (state.classname === 'func_areaportalwindow' && !this.map.portalWindows?.[instance.model.path]) continue;
				const slot=this.frame.prepared.draws?.slots.get(state.id), record=slot?.record || {id:state.id,path:instance.model.path,look:state.eye?.angles||null,body:state.body,skin:state.skin,item:!actor,ownedItem:this.owners.has(state.id),renderMode:state.render.mode};
				record.matrices=instance.matrices;record.posePair=instance.posePair;record.sky=instance.sky;record.alpha=(state.render.color>>>24)/255;
				record.rim=rim;record.xray=prefs.xray&&(survivor||type==='tank');record.outline=outline;record.tint=biled?ReplayScene.bileTint:slot?.tint || [state.render.color&255,state.render.color>>>8&255,state.render.color>>>16&255].map(v=>v/255);
				record.sprite=sprite;record.beam=state.render.beam?this.beam(instance,time):null;record.trail=state.render.trail?this.spriteTrail(instance,time):null;record.eyes=null;record.light=null;
				actors.push(record);
			}
			if (prefs.hitbox && (actor || !outside(state, 64))) this.hullLines(hitLines, state, instance, [...rgb, .8], time);
			if (!actor) {
				if (instance && ['molotov_projectile', 'vomitjar_projectile', 'pipe_bomb_projectile'].includes(state.classname)) {
					const position = instance.world.subarray ? instance.world.subarray(12, 15) : instance.world.slice(12, 15), [text, tone] = replayTypes[state.classname];
					labels.push({p:[position[0], position[1], position[2] + 14], text, color:tone});
				}
				continue;
			}
			const sky = instance?.sky ?? SourceMap.inSky(this.map, state.origin), scale = sky ? this.map.sky.scale : 1, position = instance ? Array.from(instance.world.slice(12, 15)) : this.displayPoint(state.origin, sky), height = state.hull?.maxs[2]; if (height == null) continue;
			if (survivor) groundRings.push({sphere:[...position, (followed ? 22 : 19) * scale], color:rgb});
			if (survivor || type !== 'infected') {
				const temporary = state.life === 3 ? 0 : Math.max(0, (state.buffer?.health || 0) - Math.max(0, time - (state.buffer?.time ?? time)) * (state.buffer?.rate || 0)), health = Math.max(0, state.health) + temporary, status = actorStatus(state), ability = state.team === 3 ? state.ability : null;
				const pursued = survivor && (state.life === 0 || state.life === 3) && this.witchTargets.some(track => track[replayAt(track, time)]?.[1] === state.id);
				labels.push({p:[position[0], position[1], position[2] + (height + 14) * scale], text:(survivor ? meta?.name || state.name : replayTypes[type]?.[0] || state.name) + (survivor && status !== '站立' ? ' · ' + status : ''), color, frac:health / state.maxHealth, accent:state.life === 3 ? DOWNED : health < 40 ? '#ff5b6b' : color, bot:survivor, followed:survivor && followed, pursued, ability});
			}
		}
		const corpses = [];
		// Corpses as the game shows them: a ragdoll for a while after death, then fading out
		// (cl_ragdoll-style lifetimes below). Survivors leave a survivor_death_model instead.
		const deathModels = this.frame.entities.filter(state => state.classname === 'survivor_death_model' && state.origin);
		// A survivor's body stays (like survivor_death_model) until a defibrillator brings them back or
		// the round ends: only their latest death counts, and none once they are alive again.
		const lastSurvivorDeath = new Map(); for (const event of this.deaths.values()) if (this.ui.actorById.get(event.id)?.type === 'survivor' && event.t <= time && !(lastSurvivorDeath.get(event.id)?.t > event.t)) lastSurvivorDeath.set(event.id, event);
		for (const [key, event] of this.deaths) {
			const kind = this.ui.actorById.get(event.id)?.type, survivor = kind === 'survivor', life = survivor ? Infinity : ReplayScene.corpseLife[kind] ?? ReplayScene.corpseLife.special, age = time - event.t;
			if (age > life) continue;
			// Alive again = a defib/rescue/respawn event for them after this death, or the player alive with
			// health on team 2 for a while (a dead bot can flip state/team/model as an observer; that alone
			// does not end the body). survivor_death_model entities are not drawn: this body stands for it.
			if (survivor) { if (lastSurvivorDeath.get(event.id) !== event) continue; const current = this.states.get(event.id); if (this.revivedAfter(event, time) || age > 3 && current && current.life === 0 && current.team === 2 && current.health > 1 && current.classname === 'player') continue; }
			event.fade = survivor ? 1 : clamp((life - age) / 2, 0, 1); event.survivor = survivor;
			let bounds = this.corpseBounds.get(key); const hull = event.state.hull;
			if (!bounds && hull) bounds = [...hull.mins.map((v, k) => v + event.state.origin[k]), ...hull.maxs.map((v, k) => v + event.state.origin[k])];
			if (bounds) { const margin = Math.hypot(...bounds.slice(3).map((v, k) => v - bounds[k])), near = bounds.map((v, k) => v + (k < 3 ? -margin : margin)); if (!ReplayRenderer.visible(viewPlanes, near)) continue; }
			corpses.push(event);
		}
		// Survivor bodies are outside the corpse cap; the rest nearest first.
		corpses.sort((a, b) => Number(b.survivor) - Number(a.survivor) || Math.hypot(...a.state.origin.map((v, k) => v - eye[k])) - Math.hypot(...b.state.origin.map((v, k) => v - eye[k])));
		// After a seek every corpse within its lifetime is rebuilt by simulating from its death (fixed
		// steps, so the result matches continuous playback). Catch up with a larger budget until done.
		this.ragdolls.deadline = performance.now() + (this.catchingUp ? (window.__viewer?.playing?.() ? 6 : 40) : 3);
		for (const event of corpses.slice(0, ReplayScene.corpseLimit + corpses.filter(event => event.survivor).length)) this.addRagdoll(event, actors, time);
		// Hand this frame's jobs to the workers before the GL work so they overlap. Paused, a frame whose
		// corpses are not yet at their exact pose is held back (the previous image stays) for up to
		// 120 ms while the ragdoll worker answers; a longer catch-up then shows the bodies settling.
		this.jobs?.flush(playing);
		if (!playing && this.corpseWait && this.jobs?.live && this.lastStats) { this.waitSince ||= performance.now(); if (performance.now() - this.waitSince < 120) return this.lastStats; } else this.waitSince = 0;
		const followedPlayer=this.states.get(this.camera.follow), viewmodel=this.firstPerson(followedPlayer,time);
		if(viewmodel){
			viewmodel.root=new Float32Array([view[3],view[7],view[11],0,...ReplayCamera.norm([-view[0],-view[4],-view[8]]),0,...ReplayCamera.norm([view[1],view[5],view[9]]),0,...eye,1]);
			// The gun and its flash share a short foreground depth range.
			viewmodel.view=view.slice();for(let k=2;k<16;k+=4)viewmodel.view[k]=view[k+1]*1.001;viewmodel.view[14]-=.2;
		}
		const flashes=this.shots(glow, eye, time, viewmodel);
		this.damageLabels = [];
		for (const event of this.frame.events) {
			const age = time - event.t; if (!['hurt', 'incap'].includes(event.cat) || age < 0 || age > 1.4 || !event.position) continue;
			const position = event.position, fade = 1 - age / 1.4, radius = 22 + age * 50, center = [position[0], position[1], position[2] + 3], color = [1.6, .25, .35, fade];
			for (let index = 0; index < 32; index++) { const point = (step, r) => [center[0] + Math.cos(step * Math.PI / 16) * r, center[1] + Math.sin(step * Math.PI / 16) * r, center[2]]; for (const vertex of [point(index, radius - 3), point(index, radius), point(index + 1, radius), point(index, radius - 3), point(index + 1, radius), point(index + 1, radius - 3)]) ReplayScene.vertex(glow, vertex, color); }
			this.damageLabels.push({p:[position[0], position[1], position[2] + 78], age, text:event.cat === 'incap' ? '倒地' : '−' + event.damage, incap:event.cat === 'incap'});
		}
		const overlays = [{vertices:glow.view(), additive:true, glow:1},...flashes];
		overlays.push(...ReplayThrowables.overlays(this,time));
		if (this.tongueBuffer.length) overlays.push({vertices:this.tongueBuffer.view()});
		if (hitLines.length) overlays.push({vertices:hitLines.view(), mode:'lines'});
		if (prefs.nav) overlays.push({mesh:this.navOverlay(), noDepth:true});
		if (prefs.botai && this.botai.available) { const vertices = this.botai.draw(this.frame, this.states, eye); if (vertices.length) overlays.push({vertices, noDepth:true}); }
		const span = prefs.trail === 'all' ? this.manifest.summary.duration : Number(prefs.trail), trails = span > 0 ? this.trails.map(trail => ({mesh:trail.mesh, now:time, span, color:replayRgb(this.ui.actorById.get(trail.id).color), strength:this.camera.follow === trail.id || this.camera.follow === 'team' ? .8 : .6})) : [];
		const visibilityOrigin = this.camera.mode === 'orbit' || this.camera.mode === 'top' ? this.camera.target : eye;
		const effects = SourceParticles.frame(this.map.particles || {}, this.fireParticles(time), time, eye, this.instances, this.map, visibilityOrigin), fogController = followedPlayer?.classname === 'player' ? followedPlayer.render.fogController : undefined, tonemapController = followedPlayer?.classname === 'player' ? followedPlayer.render.tonemapController : undefined;
		const coverage = SourceParticles.coverage(prefs.hitbox ? this.frame.entities : this.frame.entities.filter(state => state.volume?.type === 'acid'), this.map, time);
		const skyPerspective = this.camera.ortho && this.camera.mode !== 'top' ? this.camera.view(canvas.width / canvas.height, false) : null;
		const stats = this.renderer.render({viewmodel,flashlights,draws:this.frame.prepared.draws, effects, coverage, fogController, tonemapController, viewTeam:followedPlayer?.classname === 'player' ? followedPlayer.team : 0, width:canvas.width, height:canvas.height, view, skyPerspective, eye, focus:this.camera.target, visibilityOrigin, cut:prefs.slice && this.camera.mode !== 'first' ? (this.camera.mode === 'fly' ? this.camera.cutBase : this.camera.target[2]) + prefs.cut : 1e9, time, timeOfDay:prefs.mapLighting ? null : prefs.timeOfDay, environment:this.frame.environment, ortho:this.camera.ortho, actors, xray:actors.filter(a => a.xray), trails, overlays, groundRings, settings:{fog:prefs.fog, shadows:prefs.shadows, softShadows:prefs.softShadows, outline:prefs.outline, ao:prefs.ao, bloom:prefs.bloom, fxaa:prefs.fxaa, xray:prefs.xray, realism:prefs.charStyle === 'real', outlinePx:Math.max(1.6, canvas.height / 540)}});
		this.drawLabels(labels, view, time); if (prefs.botai && this.botai.available) this.botai.drawLabels(this.context, this.frame, this.states, eye, point => this.project(point, view), Math.min(devicePixelRatio || 1, 2)); this.drawMini(); this.ui.update(this.frame, time); this.botai.panel(this.frame, time); $('activeInfo').textContent = Object.entries(active).filter(([type]) => type !== 'survivor').map(([type, count]) => (replayTypes[type]?.[0] || type) + ' ' + count).join(' · ');
		// Continuous playback catches up the same way when corpses stay pending (many deaths at once),
		// so seeking and playing to the same time show the same corpses.
		this.pendingFrames = this.ragdolls.pending ? (this.pendingFrames || 0) + 1 : 0; if (!this.ragdolls.pending) this.catchingUp = false; else if (this.pendingFrames > 3) this.catchingUp = true;
		this.lastStats = stats; stats.culled = this.culled; stats.lod = this.lodCache.size; stats.ragdolls = this.ragdolls.bodies.size; stats.corpsePoses = this.corpsePoses.size; stats.corpsePoseBytes = this.corpsePoseBytes; stats.springs = this.springs.size; return stats;
	}
	fireParticles(time) {
		const states = this.frame.entities, sources = [];
		for (const state of states) {
			const volume = state.volume;
			if (volume?.type === 'fire') {
				const points = volume.patches.filter((_, i) => volume.expires[i] > time).map(p => p.map((v, k) => state.origin[k] + v));
				if (points.length) sources.push({id:~state.id, origin:points[0], render:{particle:{name:'molotov_groundfire', active:true, dynamic:true, start:state.start, points, highest:points.length - 1}}});
			}
		}
		for (const [id, burn] of this.burning) {
			const state = this.states.get(id);
			if (!state || state.life !== 0 || time - burn.last > 1.5) { this.burning.delete(id); continue; }
			const instance = this.instances.get(id); if (!instance) continue;
			const set = instance.descriptor.hitboxSets?.[state.render.hitboxSet]; if (!set?.boxes.length) continue;
			let boxes;
			const hitboxes = cp => {
				if (cp !== 0 && cp !== 1) return null;
				if (!boxes) {
					boxes = [];
					for (const box of set.boxes) {
						const slot = instance.descriptor.hitboxBones.indexOf(box.bone), local = slot < 0 ? -1 : this.poseBoneIds[state.model][slot];
						const bone = SourceAnimation.boneAt(instance.pose,local), world = instance.hitboxWorld?.[box.bone] ?? (bone && SourceModel.multiply(instance.nativeWorld,bone));
						if (world) boxes.push({mins:box.mins, maxs:box.maxs, world});
					}
				}
				return boxes;
			};
			const origin = Array.from(instance.nativeWorld.slice(12, 15));
			sources.push({id:~id, origin, render:{particle:{name:'burning_character', active:true, dynamic:true, start:burn.start, stopped:time - burn.last > .45, entities:[id, id], hitboxes}}});
		}
		return sources.length ? states.concat(sources) : states;
	}
	hullLines(out, state, instance, color, time) {
		if (state.hull?.solid && state.kind === 'actor') { const world = ReplayRenderer.transform(instance ? instance.state.origin : state.origin, [0, 0, 0]); ReplayScene.boxLines(out, state.hull.mins, state.hull.maxs, (instance?.sky ?? SourceMap.inSky(this.map, state.origin)) ? SourceMap.skyTransform(this.map, world) : world, color); }
		if (!instance) return;
		const collision = instance.descriptor.collision;
		if (collision && state.hull?.solid === 6) for (const [solidIndex, solid] of collision.solids.entries()) {
			const body = collision.bodies.find(body => body.index === solidIndex), bone = collision.solids.length > 1 && body ? instance.model.bones.find(bone => bone.name === body.name) : null, world = bone ? SourceModel.multiply(instance.world, SourceAnimation.boneAt(instance.pose,bone.id)) : instance.world;
			let cache = this.collisionCache.get(state.id); if (!cache) { cache = []; this.collisionCache.set(state.id, cache); }
			let entry = cache[solidIndex];
			// Collision edges are transformed once per pose; most physics props do not move.
			if (!entry || entry.solid !== solid || !ReplayScene.sameMatrix(entry.world, world)) {
				const edges = ReplayScene.solidEdges(solid), points = new Float32Array(edges.length);
				for (let i = 0; i < edges.length; i += 3) { const x = edges[i], y = edges[i + 1], z = edges[i + 2]; points[i] = world[0] * x + world[4] * y + world[8] * z + world[12]; points[i + 1] = world[1] * x + world[5] * y + world[9] * z + world[13]; points[i + 2] = world[2] * x + world[6] * y + world[10] * z + world[14]; }
				entry = cache[solidIndex] = {solid, world:Float32Array.from(world), points};
			}
			out.points(entry.points, color);
		}
		const hitboxes = instance.descriptor.hitboxSets?.[state.render.hitboxSet];
		if (hitboxes) for (const box of hitboxes.boxes) {
			const slot = instance.descriptor.hitboxBones.indexOf(box.bone);
			if (slot < 0) continue;
			let world = instance.hitboxWorld?.[box.bone];
			if (!world && state.render.bones?.length === instance.descriptor.hitboxBones.length * 6) world = this.hitboxBone(state,instance.descriptor,box.bone,time);
			if (!world && state.classname === 'infected') {
				const id = this.poseBoneIds[state.model][slot], bone = id >= 0 && SourceAnimation.boneAt(instance.pose,id);
				if (bone) world = SourceModel.multiply(instance.nativeWorld,bone);
			}
			if (world) ReplayScene.boxLines(out, box.mins, box.maxs, instance.sky ? SourceMap.skyTransform(this.map, world) : world, color);
		}
	}
	hitboxBone(state, descriptor, bone, time) {
		const slot = descriptor.hitboxBones.indexOf(bone); if (slot < 0) return null;
		const offset = slot * 6, a = state.render.bones, next = this.next.get(state.id), b = next?.model === state.model ? next.render.bones : null, blend = time !== undefined && b && this.frame.nextTime > this.frame.sampleTime ? clamp((time - this.frame.sampleTime) / (this.frame.nextTime - this.frame.sampleTime), 0, 1) : 0;
		const position = [0, 1, 2].map(k => { const value = state.origin[k] + a[offset + k] / 32; return value + (blend ? (next.origin[k] + b[offset + k] / 32 - value) * blend : 0); }), angles = [0, 1, 2].map(k => a[offset + 3 + k] / 128); let world = ReplayRenderer.transform(position, angles);
		if (blend) { const rotation = SourceAnimation.matrixQuaternion(world), target = SourceAnimation.matrixQuaternion(ReplayRenderer.transform([0, 0, 0], [0, 1, 2].map(k => b[offset + 3 + k] / 128))); world = SourceModel.quaternion(position, SourceAnimation.slerp(rotation, target, blend)); }
		for (let k = 0; k < 12; k++) world[k] *= state.render.scale; return world;
	}
	// Feet zone of each flame for a standing survivor (see SourceParticles.hazardPatches): a rounded
	// square (hull half-width + radius) over the full-contact band, capped for grounded acid at the
	// floor point + radius/3; fire shrinks above its center like the native sphere-vs-box test.
	volumeLines(out, state, color) {
		const faint = [color[0], color[1], color[2], color[3] * .45];
		for (const patch of SourceParticles.hazardPatches(state, this.map)) {
			const c = patch.center, r = patch.radius, h = patch.half, bottom = c[2] - patch.height, top = Math.min(c[2], patch.cap);
			const ring = (z, radius, tone) => { if (!(radius > 0)) return; const corners = [[h, h], [-h, h], [-h, -h], [h, -h]]; let first = null, previous = null; for (let q = 0; q < 4; q++) for (let i = 0; i <= 8; i++) { const angle = (q * 8 + i) * Math.PI / 16, point = [c[0] + corners[q][0] + Math.cos(angle) * radius, c[1] + corners[q][1] + Math.sin(angle) * radius, z]; if (previous) ReplayScene.line(out, previous, point, tone); else first = point; previous = point; } ReplayScene.line(out, previous, first, tone); };
			if (top >= bottom) { ring(top, r, color); ring(bottom, r, faint); for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) ReplayScene.line(out, [c[0] + dx * (h + r), c[1] + dy * (h + r), bottom], [c[0] + dx * (h + r), c[1] + dy * (h + r), top], faint); }
			if (!patch.acid) for (const f of [.5, .85]) ring(c[2] + r * f, Math.sqrt(1 - f * f) * r, faint);
			ReplayScene.line(out, patch.ground, c, faint); for (let k = 0; k < 3; k++) { const a = c.slice(), b = c.slice(); a[k] -= 4; b[k] += 4; ReplayScene.line(out, a, b, color); }
		}
	}
	displayPoint(point, sky) { return sky ? point.map((value, axis) => (value - this.map.sky.origin[axis]) * this.map.sky.scale) : point; }
	beam(instance, time) {
		const beam = instance.state.render.beam, scale = instance.sky ? this.map.sky.scale : 1, endpoints = [Array.from(instance.world.slice(12, 15)), instance.state.parent ? ReplayRenderer.point(instance.world, beam.end) : this.displayPoint(beam.end, instance.sky)];
		const point = index => { const id = beam.entities[index], target = this.instance(id, time); if (!target) { const origin = this.states.get(id)?.origin; return origin ? this.displayPoint(origin, instance.sky) : null; } const attachment = target.model.attachments[beam.attachments[index] - 1], matrix = attachment ? SourceModel.multiply(SourceModel.multiply(target.nativeWorld, SourceAnimation.boneAt(target.pose,attachment.bone)), SourceModel.rows(attachment.matrix)) : target.nativeWorld; return this.displayPoint(Array.from(matrix.slice(12, 15)), instance.sky); };
		if (beam.type !== 0 && beam.type !== 3) for (let end = 0; end < 2; end++) { const position = point(end ? beam.count - 1 : 0); if (position) endpoints[end] = position; }
		return {...beam, coordinateScale:scale, width:beam.width * scale, endWidth:beam.endWidth * scale, fade:beam.fade * scale, amplitude:beam.amplitude * scale, start:endpoints[0], end:endpoints[1], points:beam.type === 4 ? Array.from({length:beam.count}, (_, index) => point(index)).filter(Boolean) : undefined};
	}
	spriteTrail(instance, time) {
		const state = instance.state;
		const points = this.frame.trails[state.id]; if (!points) return null;
		const first = value => { let lo = 0, hi = points.length / 4; while (lo < hi) { const middle = (lo + hi) >> 1; if (points[middle * 4] <= value) lo = middle + 1; else hi = middle; } return lo; }, start = Math.max(0, first(time - state.render.trail.life) - 1), end = first(time);
		const segment = points.subarray(start * 4, end * 4); if (!instance.sky) return {...state.render.trail, points:segment};
		const transformed = segment.slice(), scale = this.map.sky.scale; for (let i = 0; i < transformed.length; i += 4) for (let k = 0; k < 3; k++) transformed[i + k + 1] = (transformed[i + k + 1] - this.map.sky.origin[k]) * scale;
		return {...state.render.trail, startWidth:state.render.trail.startWidth * scale, endWidth:state.render.trail.endWidth < 0 ? state.render.trail.endWidth : state.render.trail.endWidth * scale, fade:state.render.trail.fade * scale, textureResolution:state.render.trail.textureResolution / scale, points:transformed};
	}
	flashlights(time) {
		const lights = [], blend = clamp((time - this.frame.sampleTime) / (this.frame.nextTime - this.frame.sampleTime || 1), 0, 1);
		for (const player of this.frame.entities) {
			// EF_DIMLIGHT is the recorded flashlight switch, including while a survivor is incapacitated.
			if (player.team !== 2 || player.life !== 0 || !(player.render?.effects & 4) || !this.camera.hasEye(player)) continue;
			const eye = this.camera.eyeAt(player, this.next.get(player.id), blend), pose = ReplayRenderer.transform(eye.origin, eye.angles);
			let origin = ReplayRenderer.point(pose, [0,-5,-5]);
			if (this.camera.mode !== 'first' || this.camera.follow !== player.id) {
				const weapon = this.instance(player.active, time), mount = weapon?.model.attachments.find(a => a.name === 'flashlight');
				if (mount) {
					const bone = SourceAnimation.boneAt(weapon.pose, mount.bone);
					origin = ReplayRenderer.point(SourceModel.multiply(weapon.world, bone), [mount.matrix[3],mount.matrix[7],mount.matrix[11]]);
				}
			}
			pose.set(origin, 12);
			const view = SourceModel.multiply(ReplayRenderer.flashlightProjection, SourceModel.inverse(pose));
			lights.push({view, planes:ReplayRenderer.planes(view), origin, owner:player.id, inventory:player.inventory});
		}
		return lights;
	}
	shots(out, eye, time, vm) {
		const flashes=[];
		for (const event of this.frame.events) {
			if (event.name !== 'weapon_fire' || event.t > time || time - event.t > .12) continue;
			const owner = this.frame.entities.find(state => state.userid === event.userid), first = this.camera.mode === 'first' && owner?.id === this.camera.follow, age = time - event.t;
			let origin, forward;
			if(first){
				const track=vm?.clip.muzzle;if(!track || event.t<(owner.activeSince ?? 0))continue;
				const a=Math.floor(vm.frame), b=Math.min(a+1,vm.clip.frames-1), f=vm.frame-a, sample=k=>track[a*6+k]+(track[b*6+k]-track[a*6+k])*f;
				origin=ReplayRenderer.point(vm.root,[sample(0),sample(1),sample(2)]);forward=ReplayCamera.norm(ReplayRenderer.point(vm.root,[sample(3),sample(4),sample(5)],0));
			}else{
				const item=owner?.inventory.find(item=>item.active), instance=item && this.instance(item.id,time);if(!instance)continue;
				const attachment=instance.model.attachments.find(a=>/muzzle|flash/i.test(a.name));if(!attachment)continue;
				const muzzle=SourceModel.multiply(SourceModel.multiply(instance.world,SourceAnimation.boneAt(instance.pose,attachment.bone)),SourceModel.rows(attachment.matrix));
				origin=ReplayRenderer.point(muzzle,[0,0,0]);forward=ReplayCamera.norm(ReplayRenderer.point(muzzle,[1,0,0],0));
			}
			for (const impact of this.frame.events) if (impact.name === 'bullet_impact' && impact.userid === event.userid && Math.abs(impact.t - event.t) < .04 && impact.position) ReplayScene.quadLine(out, origin, impact.position, .22, [1.3, .85, .35, .32 * (1 - age / .12)], [.8, .5, .2, .02], eye);
			if (age > .05) continue;
			flashes.push({kind:7,origin,forward,age,id:0,count:3,verticesPerParticle:72,additive:true,glow:1,viewmodelView:first?vm.view:null});
		}
		return flashes;
	}
	heightColor(z) { const bounds = this.manifest.bounds, fraction = clamp((z - bounds[2]) / Math.max(1, bounds[5] - bounds[2]), 0, 1), colors = [[.15, .24, .44], [.16, .52, .52], [.61, .70, .47], [.92, .77, .49]], index = Math.min(2, Math.floor(fraction * 3)), blend = fraction * 3 - index; return colors[index].map((v, k) => v * (1 - blend) + colors[index + 1][k] * blend); }
	navOverlay() { if (!this.navMesh) { const nav = this.map.layers.nav, vertices = new Float32Array(nav.length / 3 * 7); for (let i = 0, offset = 0; i < nav.length; i += 3, offset += 7) vertices.set([nav[i], nav[i + 1], nav[i + 2], ...this.heightColor(nav[i + 2]), .55], offset); this.navMesh = this.renderer.staticOverlay(vertices); } return this.navMesh; }
	prepareMini() {
		const canvas = $('mini'), width = canvas.width = 500, height = canvas.height = 368, bounds = this.manifest.bounds; this.miniBounds = [bounds[0] - 200, bounds[1] - 200, bounds[3] + 200, bounds[4] + 200]; this.miniScale = Math.min((width - 30) / (this.miniBounds[2] - this.miniBounds[0]), (height - 40) / (this.miniBounds[3] - this.miniBounds[1]));
		this.miniBG = document.createElement('canvas'); this.miniBG.width = width; this.miniBG.height = height; const g = this.miniBG.getContext('2d'); g.fillStyle = '#0b0f17'; g.fillRect(0, 0, width, height);
		const nav = this.map.layers.nav; for (let i = 0; i < nav.length; i += 9) { g.fillStyle = `rgb(${this.heightColor(nav[i + 2]).map(v => Math.round(v * 150 + 18)).join(',')})`; g.beginPath(); for (let k = 0; k < 3; k++) { const point = this.miniXY([nav[i + k * 3], nav[i + k * 3 + 1]]); k ? g.lineTo(...point) : g.moveTo(...point); } g.closePath(); g.fill(); }
		for (const bot of this.ui.bots) { const points = this.manifest.timeline.trails[bot.id]; g.strokeStyle = bot.color + '55'; g.lineWidth = 1.2; g.beginPath(); for (let i = 0; i < points.length; i += 4) { const point = this.miniXY([points[i + 1], points[i + 2]]); if (!i || points[i] - points[i - 4] > .2 || Math.hypot(points[i + 1] - points[i - 3], points[i + 2] - points[i - 2], points[i + 3] - points[i - 1]) > 64) g.moveTo(...point); else g.lineTo(...point); } g.stroke(); }
		canvas.onclick = e => this.camera.moveTo((e.offsetX * width / canvas.clientWidth - width / 2) / this.miniScale + (this.miniBounds[0] + this.miniBounds[2]) / 2, (height / 2 + 8 - e.offsetY * height / canvas.clientHeight) / this.miniScale + (this.miniBounds[1] + this.miniBounds[3]) / 2);
	}
	miniXY(point) { return [250 + (point[0] - (this.miniBounds[0] + this.miniBounds[2]) / 2) * this.miniScale, 192 - (point[1] - (this.miniBounds[1] + this.miniBounds[3]) / 2) * this.miniScale]; }
	drawMini() {
		if (!prefs.mini) return; const g = $('mini').getContext('2d'); g.drawImage(this.miniBG, 0, 0); const center = this.miniXY(this.camera.target), radius = Math.min(90, 26 + this.camera.distance * this.miniScale * .5); g.fillStyle = 'rgba(255,255,255,.10)'; g.beginPath(); g.moveTo(...center); for (const spread of [-.55, .55]) { const angle = this.camera.yaw + Math.PI + spread; g.lineTo(center[0] + Math.cos(angle) * radius, center[1] - Math.sin(angle) * radius); } g.closePath(); g.fill();
		for (const state of this.frame.entities) { const type = actorType(state); if (state.team !== 2 && type !== 'tank' && type !== 'witch') continue; const point = this.miniXY(state.origin); g.fillStyle = actorColor(state, this.ui.actorById.get(state.id)); g.beginPath(); g.arc(...point, state.team === 2 ? 5 : 6, 0, Math.PI * 2); g.fill(); if (this.camera.follow === state.id) { g.strokeStyle = '#fff'; g.lineWidth = 2; g.beginPath(); g.arc(...point, 9, 0, Math.PI * 2); g.stroke(); } }
	}
	project(point, matrix) { const q = [0, 0, 0, 0]; for (let i = 0; i < 4; i++) q[i] = matrix[i] * point[0] + matrix[4 + i] * point[1] + matrix[8 + i] * point[2] + matrix[12 + i]; if (q[3] <= 0) return null; return [(q[0] / q[3] + 1) * this.overlay.width / 2, (1 - q[1] / q[3]) * this.overlay.height / 2, q[2] / q[3]]; }
	drawLabels(labels, view, time) {
		const g = this.context, scale = Math.min(devicePixelRatio || 1, 2), placed = [], markers = []; g.clearRect(0, 0, this.overlay.width, this.overlay.height);
		const priority = label => label.followed || label.pursued ? -1 : label.bot ? 1 : 0;
		for (const label of labels.sort((a, b) => priority(a) - priority(b))) {
			const marked = label.followed || label.pursued;
			if (!prefs.labels && !marked) continue;
			const point = this.project(label.p, view);
			if (!point || point[2] < -1 || point[2] > 1 || point[0] < 0 || point[0] > this.overlay.width || point[1] < 0 || point[1] > this.overlay.height) { if (prefs.labels && label.bot) this.edgeMarker(label, view, scale); continue; }
			if (marked) markers.push([point, label]);
			if (!prefs.labels) continue;
			let y = point[1] - (marked ? 21 * scale : 0), overlap;
			while ((overlap = placed.find(prior => Math.abs(prior[0] - point[0]) < 90 * scale && Math.abs(prior[1] - y) < 30 * scale))) y = overlap[1] - 32 * scale;
			if (marked) placed.push([point[0], point[1]]);
			placed.push([point[0], y]); this.pill(point[0], y, label, time, scale);
		}
		for (const [point, label] of markers) this.headMarkers(point, label, scale);
		if (!prefs.labels) return;
		for (const label of this.damageLabels) { const point = this.project(label.p, view); if (!point || point[2] > 1) continue; g.globalAlpha = clamp(1 - label.age / 1.4, 0, 1); g.font = `800 ${(label.incap ? 15 : 17) * scale}px "Segoe UI",system-ui,sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.lineWidth = 4 * scale; g.strokeStyle = 'rgba(30,4,8,.85)'; const y = point[1] - label.age * 34 * scale; g.strokeText(label.text, point[0], y); g.fillStyle = label.incap ? '#ffcf8a' : '#ff6b7a'; g.fillText(label.text, point[0], y); g.globalAlpha = 1; }
	}
	headMarkers(point, label, scale) {
		const g = this.context; g.save(); g.translate(point[0], point[1]); g.scale(scale, scale); g.lineJoin = 'round';
		if (label.followed) {
			g.beginPath(); g.moveTo(-8, -13); g.lineTo(8, -13); g.lineTo(0, 0); g.closePath();
			g.strokeStyle = '#10131a'; g.lineWidth = 3; g.stroke(); g.fillStyle = label.color; g.fill();
		}
		if (label.pursued) {
			g.translate(label.followed ? 20 : 0, -9); g.beginPath(); g.arc(0, 0, 6, 0, 2 * Math.PI);
			g.moveTo(-10, 0); g.lineTo(-3, 0); g.moveTo(3, 0); g.lineTo(10, 0); g.moveTo(0, -10); g.lineTo(0, -3); g.moveTo(0, 3); g.lineTo(0, 10);
			g.strokeStyle = '#241016'; g.lineWidth = 4; g.stroke(); g.strokeStyle = '#ff6576'; g.lineWidth = 2; g.stroke();
		}
		g.restore();
	}
	edgeMarker(label, view, scale) {
		const side = (id, side, fallback) => { const el = $(id); return el.offsetParent === null || el.classList.contains('closed') || document.body.classList.contains('noui') ? fallback : el.getBoundingClientRect()[side]; }, rect = [side('squad', 'right', 0) + 24, 96, side('drawer', 'left', innerWidth) - 24, side('dock', 'top', innerHeight) - 24].map(value => value * scale), point = [0, 0, 0, 0];
		for (let i = 0; i < 4; i++) point[i] = view[i] * label.p[0] + view[4 + i] * label.p[1] + view[8 + i] * label.p[2] + view[12 + i];
		const w = Math.abs(point[3]) || 1, cx = (rect[0] + rect[2]) / 2, cy = (rect[1] + rect[3]) / 2, sign = point[3] < 0 ? -1 : 1, dx = ((point[0] / w + 1) * this.overlay.width / 2 - cx) * sign, dy = ((1 - point[1] / w) * this.overlay.height / 2 - cy) * sign, k = Math.min((rect[2] - rect[0]) / 2 / Math.abs(dx || 1e-6), (rect[3] - rect[1]) / 2 / Math.abs(dy || 1e-6)), x = cx + dx * k, y = cy + dy * k, angle = Math.atan2(dy, dx), g = this.context;
		g.save(); g.translate(x, y); g.rotate(angle); g.fillStyle = label.color; g.beginPath(); g.moveTo(10 * scale, 0); g.lineTo(-6 * scale, -7 * scale); g.lineTo(-3 * scale, 0); g.lineTo(-6 * scale, 7 * scale); g.closePath(); g.fill(); g.restore(); g.font = `600 ${11 * scale}px "Segoe UI",system-ui,sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.lineWidth = 3 * scale; g.strokeStyle = 'rgba(8,10,16,.85)'; const textX = x - Math.cos(angle) * 20 * scale, textY = y - Math.sin(angle) * 16 * scale; g.strokeText(label.text.split(' ')[0], textX, textY); g.fillStyle = label.color; g.fillText(label.text.split(' ')[0], textX, textY);
	}
	pill(x, y, label, time, scale) {
		const g = this.context; g.font = `600 ${(label.bot ? 12 : 11) * scale}px "Segoe UI",system-ui,sans-serif`; const width = g.measureText(label.text).width + 26 * scale, height = (label.bot ? 25 : 24) * scale + (label.ability ? 5 * scale : 0), left = x - width / 2, top = y - height;
		g.fillStyle = 'rgba(10,13,20,.78)'; g.beginPath(); g.roundRect(left, top, width, height, 7 * scale); g.fill(); g.strokeStyle = 'rgba(255,255,255,.10)'; g.lineWidth = scale; g.stroke(); g.fillStyle = label.color; g.beginPath(); g.arc(left + 10 * scale, top + 10 * scale, 3.2 * scale, 0, Math.PI * 2); g.fill(); g.fillStyle = '#e8edf6'; g.textAlign = 'left'; g.textBaseline = 'middle'; g.fillText(label.text, left + 18 * scale, top + 11 * scale);
		if (label.frac === undefined) return;
		const barLeft = left + 6 * scale, barWidth = width - 12 * scale, hpY = top + 19 * scale; g.fillStyle = 'rgba(255,255,255,.12)'; g.fillRect(barLeft, hpY, barWidth, 2.5 * scale); g.fillStyle = label.accent; g.fillRect(barLeft, hpY, barWidth * clamp(label.frac, 0, 1), 2.5 * scale);
		if (label.ability) { const ability = label.ability, cooldown = ability.readyAt > time && ability.duration > 0, fraction = cooldown ? clamp(1 - (ability.readyAt - time) / ability.duration, 0, 1) : 1, skillY = hpY + 5 * scale; g.fillStyle = 'rgba(49,122,213,.24)'; g.fillRect(barLeft, skillY, barWidth, 2.5 * scale); g.fillStyle = '#48a7ff'; g.fillRect(barLeft, skillY, barWidth * fraction, 2.5 * scale); if (cooldown) { g.save(); g.beginPath(); g.rect(barLeft, skillY, barWidth, 2.5 * scale); g.clip(); g.strokeStyle = 'rgba(255,255,255,.8)'; g.lineWidth = scale; const offset = time * 12 % 7; for (let i = -4; i < barWidth / scale + 4; i += 7) { g.beginPath(); g.moveTo(barLeft + (i + offset) * scale, skillY + 3 * scale); g.lineTo(barLeft + (i + offset + 3) * scale, skillY); g.stroke(); } g.restore(); } }
	}
	dispose() { this.viewLoader=null;this.viewMeshes.clear();this.viewClips.clear();this.jobs?.dispose(); this.springs.clear(); this.ragdolls.bodies.clear(); this.ragdolls.cells.clear(); this.corpseBounds.clear(); this.corpsePoses.clear(); this.corpsePoseBytes = 0; this.context.clearRect(0, 0, this.overlay.width, this.overlay.height); }
	static vertex(out, point, color) { if (out.vertex) out.vertex(point[0], point[1], point[2], color); else out.push(...point, ...color); }
	static sameMatrix(a, b) { for (let k = 0; k < 16; k++) if (a[k] !== b[k]) return false; return true; }
	// Unique triangle edges of a collision solid, as local segment endpoints (cached per solid).
	static solidEdges(solid) {
		if (solid._edges) return solid._edges;
		const out = [];
		for (const hull of solid) {
			const seen = new Set(), count = hull.vertices.length / 3;
			for (let triangle = 0; triangle < hull.indices.length; triangle += 3) for (let side = 0; side < 3; side++) {
				const a = hull.indices[triangle + side], b = hull.indices[triangle + (side + 1) % 3], key = Math.min(a, b) * count + Math.max(a, b); if (seen.has(key)) continue; seen.add(key);
				out.push(hull.vertices[a * 3], hull.vertices[a * 3 + 1], hull.vertices[a * 3 + 2], hull.vertices[b * 3], hull.vertices[b * 3 + 1], hull.vertices[b * 3 + 2]);
			}
		}
		return solid._edges = new Float32Array(out);
	}
	drawTongue(smoker, time, eye) {
		const sky = SourceMap.inSky(this.map, smoker.origin), mouth = this.displayPoint(smoker.ability.mouth, sky);
		let tip = this.displayPoint(smoker.ability.tip, sky);
		// The tip target clears after impact; the held survivor still identifies their Smoker.
		const held = this.frame.entities.find(actor => actor.team === 2 && actor.status?.attacker === smoker.id);
		if (held) {
			const instance = this.instance(held.id, time), waist = instance?.model.bones.find(bone => bone.name === 'ValveBiped.Bip01_Spine');
			const bone = waist && SourceAnimation.boneAt(instance.pose, waist.id);
			if (bone) tip = ReplayRenderer.point(instance.world, bone.subarray(12, 15));
		}
		let from = mouth;
		const color = [.66, .24, .26, 1];
		for (const bend of smoker.ability.bends || []) {
			const point = this.displayPoint(bend, sky);
			ReplayScene.quadLine(this.tongueBuffer, from, point, 1.5, color, color, eye);
			from = point;
		}
		ReplayScene.quadLine(this.tongueBuffer, from, tip, 1.5, color, [.48, .15, .17, 1], eye);
	}
	static line(out, a, b, color) { this.vertex(out, a, color); this.vertex(out, b, color); }
	static boxLines(out, mins, maxs, m, color) {
		const corners = ReplayScene.corners;
		for (let i = 0; i < 8; i++) { const x = i & 1 ? maxs[0] : mins[0], y = i & 2 ? maxs[1] : mins[1], z = i & 4 ? maxs[2] : mins[2]; corners[i * 3] = m[0] * x + m[4] * y + m[8] * z + m[12]; corners[i * 3 + 1] = m[1] * x + m[5] * y + m[9] * z + m[13]; corners[i * 3 + 2] = m[2] * x + m[6] * y + m[10] * z + m[14]; }
		for (let i = 0; i < 8; i++) for (let bit = 1; bit < 8; bit <<= 1) if (!(i & bit)) { const j = i | bit; if (out.vertex) { out.vertex(corners[i * 3], corners[i * 3 + 1], corners[i * 3 + 2], color); out.vertex(corners[j * 3], corners[j * 3 + 1], corners[j * 3 + 2], color); } else this.line(out, [corners[i * 3], corners[i * 3 + 1], corners[i * 3 + 2]], [corners[j * 3], corners[j * 3 + 1], corners[j * 3 + 2]], color); }
	}
	static quadLine(out, a, b, width, colorA, colorB, eye) { const side = ReplayCamera.norm(ReplayCamera.cross(ReplayCamera.norm(b.map((v, i) => v - a[i])), eye.map((v, i) => v - a[i]))).map(v => v * width), a0 = a.map((v, i) => v - side[i]), a1 = a.map((v, i) => v + side[i]), b0 = b.map((v, i) => v - side[i]), b1 = b.map((v, i) => v + side[i]); for (const [point, color] of [[a0, colorA], [b0, colorB], [b1, colorB], [a0, colorA], [b1, colorB], [a1, colorA]]) this.vertex(out, point, color); }
};
ReplayScene.corners = new Float32Array(24);
// Seconds a corpse stays (the last two fade out) and how many simulate/draw at once (nearest first).
// Killing-blow impulse for the ragdoll, as a launch velocity (in/s) along the recorded damage force.
ReplayScene.deathImpulse = (event, kind) => {
	const impact = event.impact, state = event.state, mass = {tank:.12, witch:.75, special:.85, survivor:.6}[kind] ?? 1;
	let direction = null, magnitude = 0;
	if (impact?.force) { magnitude = Math.hypot(...impact.force); if (magnitude > 1e-3) direction = impact.force.map(v => v / magnitude); }
	if (!direction) { const yaw = (state.angles?.[1] || 0) * Math.PI / 180; direction = [-Math.cos(yaw), -Math.sin(yaw), 0]; }
	const type = (impact?.damage_type ?? 0) >>> 0, weapon = (String(impact?.weapon || '') + ' ' + String(impact?.inflictor_class || '')).toLowerCase();
	let speed = 140, lift = .12;
	const infected = state.classname === 'infected' || state.classname === 'witch' || state.classname === 'player' && kind && kind !== 'survivor';
	const fire = (type & 8) !== 0 || /entityflame|inferno/.test(impact?.inflictor_class || '');
	if (infected && fire && !(type & 64)) { speed = 40; lift = 0; }
	else if (type & 64 || /grenade|pipe_bomb|propane|explo|barrel/.test(weapon)) { speed = 520; lift = .45; }
	else if (/tank|rock/.test(weapon)) { speed = 520; lift = .35; }
	else if (type & 0x20000000 || /shotgun|spas|pumpshot|autoshot|chrome/.test(weapon)) speed = 300;
	else if (/sniper|hunting|awp|scout|50cal/.test(weapon)) speed = 290;
	else if (/minigun/.test(weapon)) speed = 220;
	else if (type & 128 || type & 4 || /melee|claw|chainsaw|knife|katana|axe|bat|crowbar|machete|guitar|pan|tonfa|club|shovel|pitchfork/.test(weapon)) { speed = 220; lift = .2; }
	else if (/pistol|magnum|deagle/.test(weapon)) speed = 110;
	else if (/smg|mp5|mac10|uzi/.test(weapon)) speed = 120;
	else if (type & 8 || /fire|burn|inferno/.test(weapon)) { speed = 40; lift = 0; }
	if (!impact) speed *= .6;
	const scale = impact?.force ? Math.max(.75, Math.min(1.5, magnitude / 1500)) : 1, v = speed * scale * mass;
	const velocity = [direction[0] * v, direction[1] * v, direction[2] * v + v * lift];
	if (infected && magnitude > .001 && (!fire || type & 64)) {
		// Retain sideways and forward momentum, but don't let a charge into the shot cancel the launch.
		const horizontal = Math.hypot(direction[0], direction[1]);
		if (horizontal > .001) {
			const x = direction[0] / horizontal, y = direction[1] / horizontal, opposing = Math.min(0, state.velocity[0]*x + state.velocity[1]*y);
			velocity[0] -= opposing*x; velocity[1] -= opposing*y;
		}
		velocity[2] = Math.max(velocity[2], Math.min(215*mass, v*.8 + 36*mass)) - Math.min(0, state.velocity[2]);
	}
	return [{position:impact?.position || [state.origin[0], state.origin[1], state.origin[2] + 50], velocity}];
};
ReplayScene.corpseLife = {common:10, special:20, tank:25, witch:25, survivor:30};
ReplayScene.corpseLimit = 24;
// Albedo multiplier for a survivor covered in Boomer bile (yellow-green).
ReplayScene.bileTint = [.74, .95, .32];
ReplayScene.fireOutline = [1, .46, .035, 1];
