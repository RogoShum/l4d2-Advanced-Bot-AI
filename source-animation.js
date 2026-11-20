'use strict';

// MDL sequence graphs and compressed animation blocks are shared by every instance.
globalThis.SourceAnimation = {
	async load(library, path, bytes, bones) {
		if (library.animations.has(path)) return library.animations.get(path);
		const pending = this.read(library, path, bytes, bones); library.animations.set(path, pending); return pending;
	},
	async read(library, path, bytes, bones) {
		bytes ||= await library.read(path); if (!bytes) throw Error('缺少动画模型：' + path);
		const d = SourceIO.view(bytes), I = at => d.getInt32(at, true), F = at => d.getFloat32(at, true), str = (at, field = 0) => I(at+field) ? SourceIO.string(bytes, at + I(at+field)) : '';
		const boundsRadius = at => Math.hypot(...[0,4,8].map(k => Math.max(Math.abs(F(at+k)), Math.abs(F(at+12+k)))));
		let renderRadius = Math.max(boundsRadius(104), boundsRadius(128));
		bones ||= Array.from({length:I(156)}, (_, id) => { const at = I(160) + id * 216; return {id, name:str(at), parent:I(at+4), position:SourceIO.floats(d,at+32,3), quaternion:SourceIO.floats(d,at+44,4), rotation:SourceIO.floats(d,at+60,3), positionScale:SourceIO.floats(d,at+72,3), rotationScale:SourceIO.floats(d,at+84,3),alignment:SourceIO.floats(d,at+144,4),flags:I(at+160)}; });
		const poseParameters = Array.from({length:I(300)}, (_, id) => { const at = I(304)+id*20; return {name:str(at), start:F(at+8), end:F(at+12), loop:F(at+16)}; });
		const animations = Array.from({length:I(180)}, (_, id) => { const at = I(184)+id*100; return {at, name:str(at,4), fps:F(at+8), flags:I(at+12), frames:I(at+16), block:I(at+52), offset:I(at+56), hierarchy:I(at+72), hierarchyOffset:I(at+76), sections:I(at+80), sectionFrames:I(at+84)}; });
		const sequences = Array.from({length:I(188)}, (_, id) => {
			const at = I(192)+id*212, size = [I(at+68),I(at+72)], poseKey = I(at+160), weights = I(at+156);
			renderRadius = Math.max(renderRadius, boundsRadius(at+32));
			return {id, name:str(at,4), activity:str(at,8), flags:I(at+12), size, parameters:[I(at+76),I(at+80)], start:[F(at+84),F(at+88)], end:[F(at+92),F(at+96)], cyclePose:I(at+180), animations:Array.from({length:I(at+56)}, (_, n) => d.getInt16(at+I(at+60)+n*2,true)), weights:weights ? Float32Array.from({length:bones.length}, (_, n) => F(at+weights+n*4)) : null,
				keys:poseKey ? size.map((count, axis) => Array.from({length:count}, (_, n) => F(at+poseKey+(axis*size[0]+n)*4))) : null,
				layers:Array.from({length:I(at+148)}, (_, n) => { const p = at+I(at+152)+n*24; return {sequence:d.getInt16(p,true), pose:d.getInt16(p+2,true), flags:I(p+4), start:F(p+8), peak:F(p+12), tail:F(p+16), end:F(p+20)}; })};
		});
		const blocks = Array.from({length:I(352)}, (_, n) => { const at = I(356)+n*8; return [I(at),I(at+4)]; });
		const external = animations.some(a => a.block || a.sections && Array.from({length:Math.floor(a.frames/Math.max(1,a.sectionFrames))+2}, (_, n) => a.at+a.sections+n*8).some(at => at+8<=bytes.length && I(at)>0));
		const aniName = I(348) ? SourceIO.string(bytes,I(348)) : '', ani = external ? await library.read(aniName || path.replace(/\.mdl$/,'.ani')) : null;
		if (external && !ani) throw Error('缺少外部动画：' + (aniName || path));
		const includes = [];
		for (let n = 0; n < I(336); n++) { const at = I(340)+n*8, name = SourceIO.path(str(at,4)); if (name && name !== path) includes.push(await this.load(library,name)); }
		const autoplay = [...new Set([...sequences.filter(sequence=>sequence.flags&8).map(sequence=>sequence.name.toLowerCase()),...includes.flatMap(source=>source.autoplay)])];
		for (const child of includes) renderRadius = Math.max(renderRadius, child.renderRadius);
		return {path, bytes, ani, blocks, bones, animations, sequences, poseParameters, includes, autoplay, renderRadius};
	},
	quat48(d, at) { const z = d.getUint16(at+4,true), q = [(d.getUint16(at,true)-32768)/32768,(d.getUint16(at+2,true)-32768)/32768,((z&32767)-16384)/16384]; q.push(Math.sqrt(Math.max(0,1-q.reduce((sum,v)=>sum+v*v,0)))*(z&32768?-1:1)); return q; },
	quat48s(d, at) { const a=d.getUint16(at,true),b=d.getUint16(at+2,true),c=d.getUint16(at+4,true),start=(a>>15)*2+(b>>15),q=[0,0,0,0]; q[start]=((a&32767)-16384)/23168; q[(start+1)%4]=((b&32767)-16384)/23168; q[(start+2)%4]=((c&32767)-16384)/23168; q[(start+3)%4]=Math.sqrt(Math.max(0,1-q.reduce((sum,v)=>sum+v*v,0)))*(c&32768?-1:1); return q; },
	quat64(d, at) { const packed = d.getBigUint64(at,true), q = [0n,21n,42n].map(shift => (Number(packed>>shift&2097151n)-1048576)/1048576.5); q.push(Math.sqrt(Math.max(0,1-q.reduce((sum,v)=>sum+v*v,0)))*(packed>>63n?-1:1)); return q; },
	euler(angle) { const [sx,sy,sz] = angle.map(v=>Math.sin(v/2)), [cx,cy,cz] = angle.map(v=>Math.cos(v/2)); return [sx*cy*cz-cx*sy*sz,cx*sy*cz+sx*cy*sz,cx*cy*sz-sx*sy*cz,cx*cy*cz+sx*sy*sz]; },
	// Hot path (every bone of every animated actor, every frame): plain arithmetic, no array callbacks.
	slerp(a, b, weight, align=true) { let dot = a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3]; const sign = align && dot < 0 ? -1 : 1; dot = Math.max(-1,Math.min(1,dot*sign)); const angle = Math.acos(dot), sine = Math.sin(angle), x = sine>.00001 ? Math.sin((1-weight)*angle)/sine : 1-weight, y = (sine>.00001 ? Math.sin(weight*angle)/sine : weight)*sign; return [a[0]*x+b[0]*y,a[1]*x+b[1]*y,a[2]*x+b[2]*y,a[3]*x+b[3]*y]; },
	quatBlend(a, b, weight, align=true) { const sign=align&&a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3]<0?-1:1,u=1-weight,w=weight*sign,x=a[0]*u+b[0]*w,y=a[1]*u+b[1]*w,z=a[2]*u+b[2]*w,s=a[3]*u+b[3]*w,length=Math.sqrt(x*x+y*y+z*z+s*s)||1;return [x/length,y/length,z/length,s/length]; },
	quatMultiply(a, b) { return [a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1],a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0],a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3],a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]]; },
	rle(d, at, frame) {
		while (true) { const valid = d.getUint8(at), total = d.getUint8(at+1); if (!total) throw Error('动画 RLE 区块长度为零'); if (frame < total) return valid ? d.getInt16(at+2*Math.min(frame+1,valid),true) : 0; frame -= total; at += (valid+1)*2; }
	},
	frame(source, animation, frame) {
		// Decoded keyframes are shared between actors playing the same animation (a horde runs the
		// same few sequences). Pose code replaces whole vectors and never writes into them, so a
		// shallow copy of the two arrays is enough. Bounded per model source.
		const cache = animation._frames || (animation._frames = new Map()), hit = cache.get(frame);
		if (hit) return {positions:hit.positions.slice(), rotations:hit.rotations.slice(), empty:hit.empty};
		const decoded = this.decodeFrame(source, animation, frame);
		if ((source._frameCount = (source._frameCount || 0) + 1) > 4096) { for (const other of source.animations || []) if (other) other._frames = null; source._frameCount = 0; animation._frames = new Map(); }
		(animation._frames || (animation._frames = new Map())).set(frame, decoded);
		return {positions:decoded.positions.slice(), rotations:decoded.rotations.slice(), empty:decoded.empty};
	},
	decodeFrame(source, animation, frame) {
		if(animation.flags&32)return {positions:source.bones.map(()=>[0,0,0]),rotations:source.bones.map(()=>[0,0,0,1]),empty:true};
		const delta = !!(animation.flags&4), positions = source.bones.map(b => delta ? [0,0,0] : b.position.slice()), rotations = source.bones.map(b => delta ? [0,0,0,1] : b.quaternion.slice());
		const header = SourceIO.view(source.bytes); let block = animation.block, offset = animation.offset, local = frame;
		if (animation.sectionFrames) { let section = Math.floor(frame/animation.sectionFrames); if (animation.frames>animation.sectionFrames && frame===animation.frames-1) { section = Math.floor(animation.frames/animation.sectionFrames)+1; local = 0; } else local %= animation.sectionFrames; const at = animation.at+animation.sections+section*8; block = header.getInt32(at,true); offset = header.getInt32(at+4,true); }
		// External animation blocks can begin at offset zero; only block -1 has no data.
		if (block === -1) return {positions,rotations};
		const bytes = block ? source.ani : source.bytes, d = SourceIO.view(bytes); let at = block ? source.blocks[block][0]+offset : animation.at+offset;
		if (animation.flags&64) {
			let constant = at+d.getInt32(at,true), animated = at+d.getInt32(at+4,true)+local*d.getInt32(at+8,true);
			for (let id = 0; id < source.bones.length; id++) {
				const flags = bytes[at+24+id];
				if (flags&64) { rotations[id] = this.quat48s(d,constant); constant += 6; }
				if (flags&2) { rotations[id] = this.quat48(d,constant); constant += 6; }
				if (flags&1) { positions[id] = [0,1,2].map(k=>SourceIO.half(d.getUint16(constant+k*2,true))); constant += 6; }
				if (flags&32) { positions[id] = SourceIO.floats(d,constant,3); constant += 12; }
				if (flags&128) { rotations[id] = this.quat48s(d,animated); animated += 6; }
				if (flags&8) { rotations[id] = this.quat48(d,animated); animated += 6; }
				if (flags&4) { positions[id] = [0,1,2].map(k=>SourceIO.half(d.getUint16(animated+k*2,true))); animated += 6; }
				if (flags&16) { positions[id] = SourceIO.floats(d,animated,3); animated += 12; }
			}
		} else while (at && bytes[at] < source.bones.length) {
			const id = bytes[at], flags = bytes[at+1], base = source.bones[id], start = at+4, rawRotation = flags&2?6:flags&32?8:0;
			if (flags&2) rotations[id] = this.quat48(d,start);
			else if (flags&32) rotations[id] = this.quat64(d,start);
			else if (flags&8) rotations[id] = this.euler(base.rotation.map((v,k) => { const offset = d.getInt16(start+k*2,true); return (flags&16?0:v)+(offset>0?this.rle(d,start+offset,local)*base.rotationScale[k]:0); }));
			if (flags&1) positions[id] = [0,1,2].map(k=>SourceIO.half(d.getUint16(start+rawRotation+k*2,true)));
			else if (flags&4) { const ptr = start+(flags&8?6:0); positions[id] = base.position.map((v,k) => { const offset = d.getInt16(ptr+k*2,true); return (flags&16?0:v)+(offset>0?this.rle(d,ptr+offset,local)*base.positionScale[k]:0); }); }
			const next = d.getUint16(at+2,true); at = next ? at+next : 0;
		}
		for(let i=0;i<source.bones.length;i++){const bone=source.bones[i];if((bone.flags&1048576)&&bone.alignment.reduce((sum,v,k)=>sum+v*rotations[i][k],0)<0)rotations[i]=rotations[i].map(v=>-v);}
		return {positions,rotations};
	},
	matrixQuaternion(m) {
		const trace=m[0]+m[5]+m[10];let q;
		if(trace>0){const s=Math.sqrt(trace+1)*2;q=[(m[6]-m[9])/s,(m[8]-m[2])/s,(m[1]-m[4])/s,s/4];}
		else if(m[0]>m[5]&&m[0]>m[10]){const s=Math.sqrt(1+m[0]-m[5]-m[10])*2;q=[s/4,(m[4]+m[1])/s,(m[8]+m[2])/s,(m[6]-m[9])/s];}
		else if(m[5]>m[10]){const s=Math.sqrt(1+m[5]-m[0]-m[10])*2;q=[(m[4]+m[1])/s,s/4,(m[9]+m[6])/s,(m[8]-m[2])/s];}
		else{const s=Math.sqrt(1+m[10]-m[0]-m[5])*2;q=[(m[8]+m[2])/s,(m[9]+m[6])/s,s/4,(m[1]-m[4])/s];}
		return q;
	},
	hierarchy(source, animation, pose, cycle, frame) {
		if(!animation.hierarchy)return pose;const d=SourceIO.view(animation.block?source.ani:source.bytes),start=(animation.block?source.blocks[animation.block][0]:animation.at)+animation.hierarchyOffset;
		for(let n=0;n<animation.hierarchy;n++){
			const at=start+n*48,bone=d.getInt32(at,true),parent=d.getInt32(at+4,true),ramp=SourceIO.floats(d,at+8,4);let index=cycle,weight=1;
			if(ramp[2]-ramp[1]<1){if(ramp[3]>1&&index<ramp[0])index++;if(index<ramp[0]||index>=ramp[3])continue;if(index<ramp[1]&&ramp[0]!==ramp[1])weight=(index-ramp[0])/(ramp[1]-ramp[0]);else if(index>ramp[2]&&ramp[2]!==ramp[3])weight=(ramp[3]-index)/(ramp[3]-ramp[2]);weight=weight*weight*(3-2*weight);}
			const compressed=at+d.getInt32(at+28,true),localFrame=Math.max(0,frame-d.getInt32(at+24,true)),first=Math.floor(localFrame),fraction=localFrame-first;
			const values=Array.from({length:6},(_,k)=>{const offset=d.getInt16(compressed+24+k*2,true);if(offset<=0)return [0,0];const scale=d.getFloat32(compressed+k*4,true);return [this.rle(d,compressed+offset,first)*scale,this.rle(d,compressed+offset,first+(fraction?1:0))*scale];});
			const position=values.slice(0,3).map(v=>v[0]+(v[1]-v[0])*fraction),rotation=this.quatBlend(this.euler(values.slice(3).map(v=>v[0])),this.euler(values.slice(3).map(v=>v[1])),fraction),world=[];
			for(let i=0;i<source.bones.length;i++){const b=source.bones[i],local=SourceModel.quaternion(pose.positions[i],pose.rotations[i]);world[i]=b.parent<0?local:SourceModel.multiply(world[b.parent],local);}
			let transform=SourceModel.quaternion(position,rotation);if(parent>=0)transform=SourceModel.multiply(world[parent],transform);const originalParent=source.bones[bone].parent;if(originalParent>=0)transform=SourceModel.multiply(SourceModel.inverse(world[originalParent]),transform);
			pose.positions[bone]=pose.positions[bone].map((v,k)=>v+(transform[12+k]-v)*weight);pose.rotations[bone]=this.slerp(pose.rotations[bone],this.matrixQuaternion(transform),weight);
		}
		return pose;
	},
	find(source, value) {
		const name = typeof value === 'object' ? value?.name : typeof value === 'string' ? value : null;
		if (name) { const cache = source._find || (source._find = new Map()); if (cache.has(name)) return cache.get(name); const match = this.findName(source, name); cache.set(name, match); return match; }
		const index=typeof value==='number'?value:value?.index,sequence=Number.isInteger(index)&&index>=0?source.sequences[index]:null;return sequence?{source,sequence}:null;
	},
	findName(source, name) {
		{ const sequence = source.sequences.find(s=>s.name.toLowerCase()===name.toLowerCase() && !(s.flags&2048)); if (sequence) return {source,sequence}; for (const child of source.includes) { const match = this.find(child,name); if (match) return match; } return null; }
	},
	parameter(source, id, values) { const parameter = source.poseParameters[id]; if (!parameter) return 0; return values.get(parameter.name.toLowerCase()) ?? parameter.start; },
	layer(root, source, layer, cycle, weight, values, local) {
		const declared=source.sequences[layer.sequence];if(!declared)return null;const match=this.find(root,declared.name);if(!match)throw Error('缺少动画层：'+declared.name);
		let layerCycle=cycle,layerWeight=weight;
		if(layer.start!==layer.end){const index=!local&&(layer.flags&16384)?this.parameter(match.source,layer.pose,values):cycle;if(index<layer.start||index>=layer.end)return null;let ramp=1;
			if(index<layer.peak&&layer.peak!==layer.start)ramp=(index-layer.start)/(layer.peak-layer.start);else if(index>layer.tail&&layer.end!==layer.tail)ramp=(layer.end-index)/(layer.end-layer.tail);
			if(layer.flags&64)ramp=ramp*ramp*(3-2*ramp);
			layerWeight=(layer.flags&128)&&index>layer.tail?ramp*weight/(1-weight+ramp*weight):(layer.flags&512)?ramp:ramp*weight;
			if(local||!(layer.flags&16384))layerCycle=(cycle-layer.start)/(layer.end-layer.start);
		}
		return {...match,cycle:layerCycle,weight:layerWeight};
	},
	axes(source, sequence, values) {
		return sequence.size.map((size, axis) => {
			if (size<2) return [0,0,0]; const value = this.parameter(source,sequence.parameters[axis],values), keys = sequence.keys?.[axis]; let position;
			if (keys) { let first = 0, fraction = (value-keys[0])/(keys[1]-keys[0] || 1); while (first<size-2 && fraction>1) { first++; fraction=(value-keys[first])/(keys[first+1]-keys[first] || 1); } position = first+Math.max(0,Math.min(1,fraction)); }
			else position = Math.max(0,Math.min(1,(value-sequence.start[axis])/(sequence.end[axis]-sequence.start[axis] || 1)))*(size-1);
			return [Math.floor(position),Math.min(size-1,Math.floor(position)+1),position-Math.floor(position)];
		});
	},
	cycleRate(source, sequence, axes) {
		let rate=0;for(let y=0;y<2;y++)for(let x=0;x<2;x++){const weight=(x?axes[0][2]:1-axes[0][2])*(y?axes[1][2]:1-axes[1][2]);if(!weight)continue;const animation=source.animations[sequence.animations[axes[1][y]*sequence.size[0]+axes[0][x]]];if(animation.frames>1)rate+=animation.fps/(animation.frames-1)*weight;}return rate;
	},
	sequence(source, sequence, cycle, values, stack = [], root = source, time) {
		if (stack.includes(sequence)) throw Error('动画层循环：' + sequence.name); stack = [...stack,sequence];
		const layerCycle=cycle,axes=this.axes(source,sequence,values);
		if (sequence.flags&256) { cycle=time*this.cycleRate(source,sequence,axes); cycle-=Math.trunc(cycle); }
		else if (sequence.flags&128) { const parameter=source.poseParameters[sequence.cyclePose]; cycle=parameter?(this.parameter(source,sequence.cyclePose,values)-parameter.start)/(parameter.end-parameter.start || 1):0; }
		cycle = sequence.flags&1 ? (cycle%1+1)%1 : Math.max(0,Math.min(1,cycle));
		const sample = (x,y) => { const animation = source.animations[sequence.animations[y*sequence.size[0]+x]]; if (!animation) throw Error('缺少序列动画：' + sequence.name); const frame = cycle*Math.max(0,animation.frames-1), first = Math.floor(frame), fraction = frame-first, a = this.frame(source,animation,first); return this.hierarchy(source,animation,fraction ? this.blend(a,this.frame(source,animation,Math.min(animation.frames-1,first+1)),fraction,source.bones,true) : a,cycle,frame); };
		const row = y => { const a = sample(axes[0][0],y); return axes[0][2] ? this.blend(a,sample(axes[0][1],y),axes[0][2],source.bones) : a; };
		let result;const x=axes[0][2],y=axes[1][2];
		if(x>0&&y>0){let corners,weights;if((axes[0][0]+axes[1][0])%2===0){if(x>y){corners=[[0,0],[1,0],[1,1]];weights=[1-x,x-y,y];}else{corners=[[1,1],[0,1],[0,0]];weights=[x,y-x,1-y];}}else if(x+y>1){corners=[[1,0],[1,1],[0,1]];weights=[1-y,x+y-1,1-x];}else{corners=[[0,1],[0,0],[1,0]];weights=[y,1-x-y,x];}
			if(weights[1]<.001){weights[1]=0;weights[2]=1-weights[0];}const poses=corners.map(([a,b],i)=>weights[i]?sample(axes[0][a],axes[1][b]):null);result=poses[0] || poses[1] || poses[2];if(weights[0]&&weights[1])result=this.blend(poses[0],poses[1],weights[1]/(weights[0]+weights[1]),source.bones);if(weights[2]&&(weights[0]||weights[1]))result=this.blend(result,poses[2],weights[2],source.bones);
		}else{result=row(axes[1][0]);if(y)result=this.blend(result,row(axes[1][1]),y,source.bones);}
		if(!result.empty&&(sequence.flags&512))for(const layer of sequence.layers)if(layer.flags&4096){const match=this.layer(root,source,layer,layerCycle,1,values,true);if(match)this.accumulate(root,match.source,match.sequence,result,source.bones,match.cycle,match.weight,values,stack,time);}
		return result;
	},
	accumulate(root,source,sequence,target,bones,cycle,weight,values,stack=[],time) {
		weight=Math.max(0,Math.min(1,weight));if(!weight || (sequence.flags&256)&&!Number.isFinite(time))return;const sampled=this.sequence(source,sequence,cycle,values,stack,root,time),mapped={positions:[],rotations:[]},weights=new Float32Array(bones.length);
		// Target-bone -> source-bone index map, built once per (source, skeleton) pair.
		const maps=source._boneMaps||(source._boneMaps=new Map());let map=maps.get(bones);
		if(!map){const lookup=new Map(source.bones.map((bone,id)=>[bone.name.toLowerCase(),id]));map=Int32Array.from(bones,bone=>lookup.get(bone.name.toLowerCase())??-1);maps.set(bones,map);}
		for(let i=0;i<bones.length;i++){const id=map[i];mapped.positions[i]=id<0?target.positions[i]:sampled.positions[id];mapped.rotations[i]=id<0?target.rotations[i]:sampled.rotations[id];weights[i]=id<0?0:sequence.weights?.[id]??1;}
		if(!sampled.empty)this.apply(target,mapped,weight,{flags:sequence.flags,weights},bones);
		for(const layer of sequence.layers)if(!(layer.flags&4096)){const match=this.layer(root,source,layer,cycle,weight,values,false);if(match)this.accumulate(root,match.source,match.sequence,target,bones,match.cycle,match.weight,values,[...stack,sequence],time);}
	},
	blend(a, b, weight, bones, align) { if (weight<=0) return a; if (weight>=1) return b; const lerp=(p,q)=>[p[0]+(q[0]-p[0])*weight,p[1]+(q[1]-p[1])*weight,p[2]+(q[2]-p[2])*weight];return {positions:a.positions.map((p,i)=>lerp(p,b.positions[i])),rotations:a.rotations.map((q,i)=>this.quatBlend(q,b.rotations[i],weight,align??!(bones[i].flags&1048576))),empty:a.empty&&b.empty}; },
	apply(a, b, weight, sequence, bones) {
		if(sequence.flags&16384){const source=[],destination=[],target=[];for(let i=0;i<bones.length;i++){const parent=bones[i].parent,w=weight*(sequence.weights?.[i]??1);source[i]=parent<0?b.rotations[i]:this.quatMultiply(source[parent],b.rotations[i]);destination[i]=parent<0?a.rotations[i]:this.quatMultiply(destination[parent],a.rotations[i]);target[i]=w?this.slerp(destination[i],source[i],w):parent<0?a.rotations[i]:this.quatMultiply(target[parent],a.rotations[i]);if(w){a.rotations[i]=parent<0?target[i]:this.quatMultiply([-target[parent][0],-target[parent][1],-target[parent][2],target[parent][3]],target[i]);if(parent>=0)a.positions[i]=a.positions[i].map((v,k)=>v+(b.positions[i][k]-v)*w);}}return a;}
		for (let i = 0; i < a.positions.length; i++) { const w = weight*(sequence.weights?.[i] ?? 1); if (!w) continue; if (sequence.flags&4) { const p = a.positions[i], d = b.positions[i]; a.positions[i] = [p[0]+d[0]*w,p[1]+d[1]*w,p[2]+d[2]*w]; const q = this.slerp([0,0,0,1],b.rotations[i],w); a.rotations[i] = sequence.flags&16 ? this.quatMultiply(a.rotations[i],q) : this.quatMultiply(q,a.rotations[i]); } else { const p = a.positions[i], q = b.positions[i]; a.positions[i] = [p[0]+(q[0]-p[0])*w,p[1]+(q[1]-p[1])*w,p[2]+(q[2]-p[2])*w]; a.rotations[i] = this.slerp(a.rotations[i],b.rotations[i],w,!(bones[i].flags&1048576)); } }
		return a;
	},
	sample(model, state = {}) {
		const animation = model.animation, positions = model.bones.map(b=>b.position.slice()), rotations = model.bones.map(b=>b.quaternion.slice()), values = new Map();
		const parameters=state.poseParameters || animation.poseParameters, names=state.poseNames || parameters.map(p=>p.name);
		for (let i=0;i<names.length;i++) { const parameter=parameters.find(p=>p.name.toLowerCase()===names[i].toLowerCase()); if(parameter)values.set(names[i].toLowerCase(),parameter.start+(parameter.end-parameter.start)*(state.pose?.[i] ?? 0)); }
		const accumulate = (value,cycle,weight) => {
			const index=typeof value==='number'?value:value?.index,name=typeof value==='string'?value:value?.name;
			if(!(typeof name==='string'&&name.length)&&!(Number.isInteger(index)&&index>=0))return;
			const match = this.find(animation,value); if (!match) throw Error('模型缺少录像序列：' + model.path + ' / ' + (value?.name ?? value));
			this.accumulate(animation,match.source,match.sequence,{positions,rotations},model.bones,cycle,weight,values,[],state.time);
		};
		if (animation.sequences.length || animation.includes.length) { accumulate(state.sequence,state.cycle ?? 0,1); for (const layer of [...(state.overlays || [])].sort((a,b)=>a.order-b.order)) if (layer.weight>0) accumulate(layer.sequence,layer.cycle,layer.weight); }
		for (const name of animation.autoplay || []) { const match = this.find(animation,name); if (match && match.sequence.flags&8) { const rate=this.cycleRate(match.source,match.sequence,this.axes(match.source,match.sequence,values));if(rate&&!Number.isFinite(state.time))continue;const cycle=rate?(state.time*rate)%1:0;this.accumulate(animation,match.source,match.sequence,{positions,rotations},model.bones,cycle,1,values,[],state.time); } }
		for (const bone of model.bones) if (bone.proc===2 && bone.quatInterp?.triggers.length) { const helper=this.quaternionHelper(bone.quatInterp,rotations[bone.quatInterp.control]);positions[bone.id]=helper.position;rotations[bone.id]=helper.rotation; }
		const bones = [], skin = [], locals = [];
		for (let i = 0; i < model.bones.length; i++) { const bone = model.bones[i], local = SourceModel.quaternion(positions[i],rotations[i]); locals[i] = local; bones[i] = bone.parent<0 ? local : SourceModel.multiply(bones[bone.parent],local); skin[i] = SourceModel.multiply(bones[i],bone.bindInverse ||= SourceModel.rows(bone.inverse)); }
		return {bones,skin,locals};
	},
	quaternionHelper(helper, control) {
		const weights=helper.triggers.map(trigger=>Math.max(0,1-2*Math.acos(Math.min(1,Math.abs(trigger.trigger.reduce((sum,v,k)=>sum+v*control[k],0))))*trigger.invTolerance)),total=weights.reduce((sum,v)=>sum+v,0),position=[0,0,0],rotation=[0,0,0,0];
		if(total<.001)return {position:helper.triggers[0].pos.slice(),rotation:helper.triggers[0].quat.slice()};
		for(let i=0;i<weights.length;i++){const trigger=helper.triggers[i],weight=weights[i]/total,sign=rotation.reduce((sum,v,k)=>sum+v*trigger.quat[k],0)<0?-1:1;for(let k=0;k<3;k++)position[k]+=trigger.pos[k]*weight;for(let k=0;k<4;k++)rotation[k]+=trigger.quat[k]*weight*sign;}
		const length=Math.hypot(...rotation)||1;return {position,rotation:rotation.map(v=>v/length)};
	},
	procedural(model, pose, world, time, springs) {
		if (!model.bones.some(bone=>bone.proc===5)) return pose;
		const inverse = SourceModel.inverse(world), transformed = [], bones = [], skin = [], locals = [];
		for (const bone of model.bones) {
			const parent=bone.parent<0 ? world : transformed[bone.parent];
			let matrix = SourceModel.multiply(parent,pose.locals[bone.id]);
			if (bone.proc===5) matrix = this.jiggle(bone,matrix,time,springs);
			locals[bone.id]=bone.proc===5 ? SourceModel.multiply(SourceModel.inverse(parent),matrix) : pose.locals[bone.id];
			transformed[bone.id]=matrix; bones[bone.id]=SourceModel.multiply(inverse,matrix); skin[bone.id]=SourceModel.multiply(bones[bone.id],bone.bindInverse ||= SourceModel.rows(bone.inverse));
		}
		return {bones,skin,locals};
	},
	overrideBones(model, pose, overrides) {
		// Overrides are sparse model-space matrices indexed by this model's original bone IDs.
		const bones=[],skin=[],locals=[];
		for(const bone of model.bones){
			const override=overrides[bone.id],local=pose.locals[bone.id];
			bones[bone.id]=override || (bone.parent<0?local:SourceModel.multiply(bones[bone.parent],local));
			locals[bone.id]=override ? (bone.parent<0?override:SourceModel.multiply(SourceModel.inverse(bones[bone.parent]),override)) : local;
		}
		// Some helpers precede their control bone, so evaluate them after all corrected locals exist.
		for(const bone of model.bones)if(!overrides[bone.id] && bone.proc===2 && bone.quatInterp?.triggers.length){const helper=this.quaternionHelper(bone.quatInterp,this.matrixQuaternion(locals[bone.quatInterp.control]));locals[bone.id]=SourceModel.quaternion(helper.position,helper.rotation);}
		for(const bone of model.bones){
			const override=overrides[bone.id];bones[bone.id]=override || (bone.parent<0?locals[bone.id]:SourceModel.multiply(bones[bone.parent],locals[bone.id]));
			if(override)locals[bone.id]=bone.parent<0?override:SourceModel.multiply(SourceModel.inverse(bones[bone.parent]),override);
			skin[bone.id]=SourceModel.multiply(bones[bone.id],bone.bindInverse ||= SourceModel.rows(bone.inverse));
		}
		return {bones,skin,locals};
	},
	boneAt(pose,id) { return pose.at ? pose.at(id) : pose.bones[id]; },
	mergeMap(model,parentModel) {
		const maps=model.mergeMaps ||= new WeakMap(); let ids=maps.get(parentModel);
		if (!ids) { const lookup=new Map(parentModel.bones.map(b=>[b.name.toLowerCase(),b.id])); ids=Int32Array.from(model.bones,b=>lookup.get(b.name.toLowerCase()) ?? -1); maps.set(parentModel,ids); }
		return ids;
	},
	boneMerge(model, pose, parentModel, parentPose, parentWorld, world) {
		const ids=this.mergeMap(model,parentModel),relative=SourceModel.multiply(SourceModel.inverse(world),parentWorld),overrides=[];
		for(const bone of model.bones){const parent=ids[bone.id];if(parent>=0)overrides[bone.id]=SourceModel.multiply(relative,this.boneAt(parentPose,parent));}
		return this.overrideBones(model,pose,overrides);
	},
	jiggle(bone, rest, time, springs) {
		const j=bone.jiggle; if (!(j.flags&67)) return rest;
		const normalize=vector=>{const n=Math.hypot(...vector)||1;return vector.map(v=>v/n);},dot=(a,b)=>a.reduce((sum,v,k)=>sum+v*b[k],0),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
		const scale=Math.hypot(rest[0],rest[1],rest[2]),left=normalize([rest[0],rest[1],rest[2]]),up=normalize([rest[4],rest[5],rest[6]]),forward=normalize([rest[8],rest[9],rest[10]]),base=[rest[12],rest[13],rest[14]],length=j.length*scale,goal=base.map((v,k)=>v+forward[k]*length);
		let spring=springs.get(bone.id);if(!spring || time<spring.time || time-spring.time>.25){spring={tip:goal.slice(),velocity:[0,0,0],base:base.slice(),baseVelocity:[0,0,0],baseAcceleration:[0,0,0],time};springs.set(bone.id,spring);}
		const dt=time-spring.time,steps=Math.min(30,Math.ceil(dt*120)),h=steps?dt/steps:0;
		if(j.flags&64)for(let step=0;step<steps;step++){
			const previous=spring.base.slice();for(let k=0;k<3;k++){spring.baseVelocity[k]+=(spring.baseAcceleration[k]+j.baseStiffness*(base[k]-spring.base[k])-j.baseDamping*spring.baseVelocity[k]-(k===2?j.baseMass:0))*h;spring.base[k]+=spring.baseVelocity[k]*h;spring.baseAcceleration[k]=0;}
			const axes=[left,up,forward],error=spring.base.map((v,k)=>v-base[k]),local=axes.map(axis=>dot(axis,error)),velocity=axes.map(axis=>dot(axis,spring.baseVelocity));
			for(let axis=0;axis<3;axis++){const [min,max,friction]=j.baseLimits[axis];if(local[axis]<min*scale||local[axis]>max*scale){local[axis]=clamp(local[axis],min*scale,max*scale);for(let other=0;other<3;other++)if(other!==axis)for(let k=0;k<3;k++)spring.baseAcceleration[k]-=friction*velocity[other]*axes[other][k];}}
			for(let k=0;k<3;k++){spring.base[k]=base[k]+axes.reduce((sum,axis,n)=>sum+axis[k]*local[n],0);spring.baseVelocity[k]=(spring.base[k]-previous[k])/h;}
		}
		if(!(j.flags&3)){spring.time=time;const result=rest.slice();for(let k=0;k<3;k++)result[12+k]=spring.base[k];return result;}
		for(let step=0;step<steps;step++){
			const error=goal.map((v,k)=>v-spring.tip[k]),ax=j.yawStiffness*dot(left,error)-j.yawDamping*dot(left,spring.velocity),ay=j.pitchStiffness*dot(up,error)-j.pitchDamping*dot(up,spring.velocity),az=j.alongStiffness*dot(forward,error)-j.alongDamping*dot(forward,spring.velocity);
			for(let k=0;k<3;k++){spring.velocity[k]+=(left[k]*ax+up[k]*ay+forward[k]*az-(k===2?j.tipMass:0))*h;spring.tip[k]+=spring.velocity[k]*h;}
			let direction=normalize(spring.tip.map((v,k)=>v-base[k]));
			if(j.flags&16 && j.angleLimit>0){const cosine=clamp(dot(direction,forward),-1,1),angle=Math.acos(cosine);if(angle>j.angleLimit){const factor=Math.sin(j.angleLimit)/Math.max(.0001,Math.sin(angle));direction=normalize(forward.map((v,k)=>v*Math.cos(j.angleLimit)+(direction[k]-v*cosine)*factor));}}
			if(j.flags&12){let x=dot(direction,left),y=dot(direction,up),z=dot(direction,forward);if(j.flags&4){const radius=Math.hypot(x,z),yaw=clamp(Math.atan2(x,z),j.minYaw,j.maxYaw);x=radius*Math.sin(yaw);z=radius*Math.cos(yaw);}if(j.flags&8){const radius=Math.hypot(y,z),pitch=clamp(Math.atan2(y,z),j.minPitch,j.maxPitch);y=radius*Math.sin(pitch);z=radius*Math.cos(pitch);}direction=normalize(left.map((v,k)=>v*x+up[k]*y+forward[k]*z));}
			const radial=dot(spring.velocity,direction);spring.velocity=spring.velocity.map((v,k)=>v-direction[k]*radial);spring.tip=base.map((v,k)=>v+direction[k]*length);
		}
		spring.time=time;const z=normalize(spring.tip.map((v,k)=>v-base[k])),x=normalize(cross(up,z)),y=cross(z,x);return new Float32Array([...x.map(v=>v*scale),0,...y.map(v=>v*scale),0,...z.map(v=>v*scale),0,...(j.flags&64?spring.base:base),1]);
	},
	matrices(model, state, world) { const pose = this.sample(model,state), out = new Float32Array(model.used.length*16); for (let i = 0; i < model.used.length; i++) SourceModel.multiply(world,pose.skin[model.used[i]],out,i*16); return out; }
};
