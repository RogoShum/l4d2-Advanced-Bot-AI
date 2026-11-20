'use strict';

// PCF definitions supply the material, emission schedule and particle operators.
globalThis.SourceParticles = {
	dmx(bytes) {
		const header=SourceIO.string(bytes,0),match=header.match(/dmx encoding binary (\d+) format pcf (\d+)/);if(!match)throw Error('粒子文件需要 binary DMX PCF');
		const version=Number(match[1]);if(version<1||version>5)throw Error('不支持的粒子DMX版本：'+version);
		const d=SourceIO.view(bytes);let p=header.indexOf('>')+3;const int=()=>{const v=d.getInt32(p,true);p+=4;return v;},short=()=>{const v=d.getUint16(p,true);p+=2;return v;},float=()=>{const v=d.getFloat32(p,true);p+=4;return v;},string=()=>{const start=p;while(bytes[p])p++;return SourceIO.text(bytes.subarray(start,p++));};
		const dictionary=version>1?Array.from({length:version<4?short():int()},string):[],name=()=>version===1?string():dictionary[version<5?short():int()],elements=[];
		for(let count=int();count>0;count--){const type=name(),label=version<4?string():name();p+=16;elements.push({type,name:label});}
		const value=(type,array=false)=>{if(type===1){const id=int();if(id===-2){string();return null;}return id<0?null:elements[id];}if(type===2)return int();if(type===3)return float();if(type===4)return !!bytes[p++];if(type===5)return version<4||array?string():name();if(type===6){const size=int();const data=bytes.slice(p,p+size);p+=size;return data;}if(type===7){if(version<3){p+=16;return null;}return int()/10000;}if(type===8)return Array.from({length:4},()=>bytes[p++]);const lengths={9:2,10:3,11:4,12:3,13:4,14:16};if(lengths[type])return Array.from({length:lengths[type]},float);throw Error('不支持的DMX属性：'+type);};
		for(const element of elements)for(let count=int();count>0;count--){const key=name(),type=bytes[p++];element[key]=type>14?Array.from({length:int()},()=>value(type-14,true)):value(type);}
		return elements.filter(element=>element.type==='DmeParticleSystemDefinition');
	},
	operator(node) { return String(node.functionName || node.name || '').toLowerCase().replace(/[ _-]/g,''); },
	field(index) { return ({1:'life',3:'radius',4:'rotation',5:'rotationSpeed',7:'alpha',8:'born',9:'sequence',10:'trail',12:'yaw',16:'alpha2'})[index]; },
	lifetime(definition) {
		let life=1;for(const init of definition.initializers || []){const kind=this.operator(init);if(kind==='lifetimerandom')life=Number(init.lifetime_max ?? init.lifetime_min ?? 1);else if(kind==='lifetimefromsequence')life=Math.max(...(definition.material?.texture?.sheet || []).map(sheet=>(sheet.duration || sheet.frames.length)/Math.max(.001,Number(init['Frames Per Second'] ?? 30))),1/60);}return life;
	},
	async load(library, names, mapName) {
		if(!names?.length)return {};
		const files=new Set();for(const path of ['particles/particles_manifest.txt','maps/'+mapName+'_particles.txt']){const data=await library.read(path);if(data)for(const match of SourceIO.text(data).matchAll(/"file"\s*"!?([^"]+)"/gi))files.add(SourceIO.path(match[1]));}
		const definitions=new Map();
		for(const path of files){const bytes=await library.read(path);if(!bytes){library.warnings.add('缺少粒子文件 '+path);continue;}try{for(const definition of this.dmx(bytes))definitions.set(definition.name,definition);}catch(error){library.warnings.add(path+': '+error.message);}}
		const selected={},visiting=new Set(),supported=new Set(['emitcontinuously','emitinstantaneously','renderanimatedsprites','rendersprites','positionwithinsphererandom','positionwithinsphere','positionwithinboxrandom','positionwithinbox','positionmodifyoffsetrandom','positionoffsetrandom','lifetimerandom','radiusrandom','alpharandom','colorrandom','rotationrandom','rotationspeedrandom','sequencerandom','velocityrandom','lifespandecay','alphafadeanddecay','alphafade','alphafadeinrandom','alphafadeoutrandom','movementbasic','basicmovement','radiusscale','colorfade','rotationbasic','rotationmovement','rotationspinroll','rotationspin','movementmatchparticlevelocities',"setcontrolpointtoparticles'center",'oscillatevector','movementmaxvelocity','renderspritetrail','randomforce','pulltowardscontrolpoint','constraindistancetocontrolpoint','rotationyawfliprandom','velocitynoise','twistaroundaxis','collisionviatraces','remapinitialscalar','remapinitialdistancetocontrolpointtoscalar','movementlocktocontrolpoint','rotationyawrandom']);
		for(const kind of ['lifetimefromsequence','remapnoisetoscalar','remapscalartovector','positionmodifywarprandom','positiononmodelrandom','movementlocktobone','remapdistancetocontrolpointtoscalar','lifetimepreagenoise','oscillatescalar','setcontrolpointpositions','renderscreenvelocityrotate'])supported.add(kind);
		const collect=async name=>{if(selected[name]||visiting.has(name))return;visiting.add(name);const definition=definitions.get(name);if(!definition){library.warnings.add('缺少原生粒子定义 '+name);return;}
			const children=[];for(const child of definition.children || []){const childName=typeof child.child==='string'?child.child:child.child?.name;if(childName){children.push({name:childName,delay:child.delay || 0});await collect(childName);}}
			const unsupported=[];for(const category of ['emitters','initializers','operators','renderers','forces','constraints'])for(const node of definition[category] || [])if(!supported.has(this.operator(node)))unsupported.push(node.functionName || node.name);
			if(unsupported.length)library.warnings.add('粒子 '+name+' 存在未重建算子：'+[...new Set(unsupported)].join('、'));
			const material=definition.material?await library.material(definition.material):null;
			selected[name]={...definition,children,material,unsupported};visiting.delete(name);
		};
		for(const name of names)await collect(name);return selected;
	},
	// Native fire/acid contact (CInferno::InfernoThink -> FUN_10383cd0, as modelled in
	// tools/offline_simulation.py and BotAI Hazards.AttackRisk): a victim is touched when the point
	// of its collision AABB nearest a flame center lies within the flame radius (60), and a map trace
	// (mask 0x4003) from the center to that point is clear. A grounded victim of acid is exempt when
	// its feet are more than radius/3 (20) above the flame's floor point. Painted surfaces are the
	// feet positions of a standing survivor hull (16 x 16 x 71 half-width/height) that pass this test;
	// the trace (walls, floors between) is not evaluated here.
	hazardPatches(state, map) {
		const volume = state.volume; if (!volume?.centers?.length) return [];
		const sky = SourceMap.inSky(map, state.origin), scale = sky ? map.sky.scale : 1, place = point => sky ? point.map((v, k) => (v - map.sky.origin[k]) * scale) : point, acid = volume.type === 'acid', out = [];
		for (let patch = 0; patch < volume.centers.length; patch++) {
			const center = volume.centers[patch].map((v, k) => v + state.origin[k]), ground = volume.patches?.[patch] ? volume.patches[patch].map((v, k) => v + state.origin[k]) : [center[0], center[1], center[2] - 40];
			const cap = acid ? ground[2] + (volume.groundedHeight ?? volume.radius / 3) : Infinity;
			out.push({center:place(center), ground:place(ground), radius:volume.radius * scale, cap:acid ? place([0, 0, cap])[2] : Infinity, half:16 * scale, height:71 * scale, acid, sky});
		}
		return out;
	},
	coverage(states, map, time) {
		const rows=[];
		for(const state of states){
			const volume=state.volume;if(!volume||!volume.centers.length||volume.expires.every(until=>time>=until))continue;
			const patches=[],bounds=[Infinity,Infinity,Infinity,-Infinity,-Infinity,-Infinity];
			// CheckTouching keeps every internal center until the whole inferno expires.
			for(const patch of this.hazardPatches(state,map)){
				const c=patch.center,reach=patch.radius+patch.half,top=Math.min(c[2]+patch.radius,patch.cap);
				patches.push(...c,patch.radius,patch.ground[2],Number.isFinite(patch.cap)?patch.cap-patch.ground[2]:1e6,patch.half,patch.height);
				bounds[0]=Math.min(bounds[0],c[0]-reach);bounds[1]=Math.min(bounds[1],c[1]-reach);bounds[2]=Math.min(bounds[2],c[2]-patch.height-patch.radius);
				bounds[3]=Math.max(bounds[3],c[0]+reach);bounds[4]=Math.max(bounds[4],c[1]+reach);bounds[5]=Math.max(bounds[5],top);
			}
			if(patches.length)rows.push(...bounds.slice(0,3),patches.length/8,...bounds.slice(3),volume.type==='acid'?1:2,...patches);
		}
		return new Float32Array(rows);
	},
	frame(definitions, states, time, eye, instances, map, focus = eye) {
		const effects=[],byId=new Map(states.map(state=>[state.id,state]));
		for(const state of states){
			const particle=state.render?.particle,def=definitions[particle?.name];if(!particle?.active||!def)continue;
			const sky=instances?.get(state.id)?.sky ?? SourceMap.inSky(map,state.origin),nativeEye=sky?eye.map((v,k)=>v/map.sky.scale+map.sky.origin[k]):eye,origin=instances?.get(state.id)?.nativeWorld?.slice(12,15) || state.origin;
			const nativeFocus=sky?focus.map((v,k)=>v/map.sky.scale+map.sky.origin[k]):focus;
			if(Math.hypot(...origin.map((v,k)=>v-nativeFocus[k]))>Number(def['maximum draw distance'] ?? 100000))continue;
			// A control point is resolved when it is CP0 (the system), bound to an entity, or recorded with a
			// real position. Recorded points that stayed (0,0,0) were never set by the game (e.g. the ground
			// control points of tank_rock_throw_rock and its debris/dust children on the parented system)
			// fall back to the system's own position instead of the world origin (debris showed in the
			// middle of a c6m3 road); children that read an unresolved CP>0 are not drawn at all.
			const supplied=index=>particle.dynamic ? !!particle.points?.[index] : !!particle.points?.[index]?.some(v=>v!==0);
			const resolved=index=>index===0||!!byId.get(particle.entities?.[index])||supplied(index)||!!(index===1&&particle.hitboxes);
			const root={resolved,point:index=>{const id=particle.entities?.[index],instance=instances?.get(id);return instance?Array.from(instance.nativeWorld.slice(12,15)):byId.get(id)?.origin || (supplied(index) ? particle.points[index] : Array.from(origin));},basis:index=>{const id=particle.entities?.[index],instance=instances?.get(id),owner=byId.get(id) || state;return instance?.nativeWorld || ReplayRenderer.transform(owner.origin,owner.angles || [0,0,0]);},highest:particle.highest ?? 0,hitboxes:particle.hitboxes,dynamic:particle.dynamic,stopped:particle.stopped,sky,eye:nativeEye,visibilityOrigin:nativeFocus};
			effects.push({name:particle.name,root,seed:state.id,key:state.id+':'+particle.name+':'+(particle.start || 0),target:time-(particle.start || 0)});
		}
		return effects;
	},
	// Control points a definition reads (any '... control point ...' number field), cached.
	usedPoints(definition) {
		if(definition._points)return definition._points;const found=new Set(),walk=node=>{if(!node||typeof node!=='object')return;for(const [key,value] of Object.entries(node)){if(key==='children')continue;if(/control[ _]?point[ _]?number/i.test(key)&&!/input|count|to set/i.test(key)){const n=Number(value);if(Number.isInteger(n)&&n>0)found.add(n);}else if(typeof value==='object')walk(value);}};
		for(const key of ['emitters','initializers','operators','renderers','forces','constraints'])walk(definition[key]);
		for(const node of definition.operators || [])if(this.operator(node)==='setcontrolpointpositions')for(const [i,word] of ['First','Second','Third','Fourth'].entries())found.delete(Number(node[word+' Control Point Number'] ?? i+1));
		return definition._points=[...found];
	},
	strength(op,time) {
		const a=Number(op['operator start fadein'] || 0),b=Number(op['operator end fadein'] || 0),c=Number(op['operator start fadeout'] || 0),d=Number(op['operator end fadeout'] || 0);
		if(time<a)return 0;if(time<b)return (time-a)/(b-a);if(d>0&&time>=c)return Math.max(0,(d-time)/(d-c || 1));return 1;
	},
	clamp(value) { return Math.max(0,Math.min(1,value)); },
	noiseTables() {
		const float=new Float32Array(1),integer=new Uint32Array(float.buffer);
		return {float,integer,a:[66,147,106,213,89,115,239,25,171,175,9,114,141,226,118,128,41,208,4,56,180,248,43,82,246,219,94,245,133,131,222,103,160,130,168,145,238,38,23,6,236,67,99,2,70,232,80,209,1,3,68,65,102,210,13,73,55,252,187,170,22,36,52,181,117,163,46,79,166,224,148,75,113,95,156,185,220,164,51,142,161,35,206,251,45,136,197,190,132,32,218,127,63,27,137,93,242,20,189,108,183,122,139,191,249,253,87,98,69,0,144,64,24,214,97,116,158,42,107,15,53,212,83,111,152,240,74,237,62,77,205,149,26,151,178,204,91,176,234,49,154,203,33,221,125,134,165,124,86,39,37,60,150,157,179,109,110,44,159,153,5,100,10,207,40,186,96,215,143,162,230,184,101,54,174,247,76,59,241,223,192,84,104,78,169,146,138,30,48,85,233,19,29,92,126,17,199,250,31,81,188,225,28,112,88,11,182,173,211,129,194,172,14,120,200,167,135,12,177,227,229,155,201,61,105,195,193,244,235,58,8,196,123,254,16,18,50,121,71,243,90,57,202,119,255,47,7,198,228,21,217,216,231,140,72,34],b:[123,108,201,64,40,75,24,221,137,110,191,142,9,69,230,83,7,247,51,54,115,133,180,248,109,116,62,99,251,55,89,253,65,106,228,167,131,132,58,143,97,102,163,202,149,234,12,117,174,94,121,74,32,113,20,60,159,182,204,29,244,118,3,178,255,38,6,114,36,93,30,134,213,90,245,209,88,232,162,125,84,166,70,136,208,231,27,71,157,80,76,0,170,225,203,176,33,161,196,128,252,236,246,2,138,1,250,197,77,243,218,242,19,164,68,212,14,237,144,63,46,103,177,188,85,223,8,160,222,4,216,219,35,15,44,23,126,127,100,226,235,37,168,101,49,22,11,73,61,135,111,183,72,96,185,239,82,18,50,155,186,153,17,233,146,156,107,5,254,10,192,198,148,207,104,13,124,48,95,129,120,206,199,81,249,91,150,210,119,240,122,194,92,34,28,205,175,227,179,220,140,152,79,26,195,47,66,173,169,241,53,184,187,145,112,238,214,147,98,171,229,200,151,25,67,78,189,217,130,224,57,172,59,41,43,16,105,158,165,21,45,56,141,139,215,190,86,42,52,39,87,181,31,154,193,211],c:[97,65,96,25,122,26,219,85,148,251,102,0,140,130,136,213,138,60,236,52,178,131,115,183,144,78,147,168,39,45,169,70,57,146,67,142,252,216,28,54,86,222,194,200,48,5,205,125,214,56,181,255,196,155,37,218,153,208,66,242,73,248,206,61,62,246,177,2,197,107,162,152,89,41,6,160,94,8,201,38,235,228,165,93,111,239,74,231,121,47,166,221,157,64,77,244,29,105,150,123,190,191,225,118,133,42,10,84,185,159,124,132,240,180,44,1,9,19,99,254,12,207,186,71,234,184,11,20,16,193,139,175,98,59,113,27,170,230,91,187,46,156,249,108,195,171,114,14,188,82,192,233,24,32,241,87,164,90,43,163,245,92,40,215,55,226,15,3,112,158,250,172,22,227,137,35,128,145,247,161,119,80,217,189,81,7,63,202,120,223,83,179,4,106,199,229,95,53,50,33,182,72,143,23,243,75,18,173,141,167,198,204,58,174,237,17,129,238,127,31,101,176,36,30,110,209,34,203,135,232,68,149,49,134,126,212,79,76,117,104,210,211,224,253,100,220,109,116,88,13,151,154,69,21,51,103],impulse:[0.788235,0.541176,0.972549,0.082353,0.352941,0.811765,0.286275,0.752941,0.203922,0.705882,0.537255,0.886275,0.580392,0.137255,0.8,0.533333,0.117647,0.447059,0.129412,0.92549,0.086275,0.478431,0.666667,0.568627,0.678431,0.313725,0.321569,0.34902,0.988235,0.419608,0.898039,0.219608,0.243137,0.623529,0.501961,0.772549,0.952941,0.517647,0.94902,0.701961,0.454902,0.505882,0.564706,0.960784,0.207843,0.007843,0.831373,0.184314,0.576471,0.462745,0.572549,0.247059,0.262745,0.694118,0.615686,0.121569,0.384314,0.74902,0.145098,0.717647,0.415686,0.607843,0.105882,0.101961,0.2,0.807843,0.521569,0.780392,0.466667,0.552941,0.996078,0.627451,0.992157,0.529412,0.407843,0.011765,0.709804,0.458824,0.058824,0.819608,0.176471,0.317647,0.392157,0.223529,0.156863,0.490196,0.32549,0.07451,0.239216,0.164706,0.890196,0.603922,0.921569,0.839216,0.854902,0.098039,0.686275,0.843137,0.152941,0.372549,0.062745,0.47451,0.486275,0.227451,0.4,0.298039,0.309804,0.27451,0.054902,0.815686,0.647059,0.635294,0.662745,0.976471,0.094118,0.509804,0.65098,0.211765,0.180392,0.003922,0.827451,0.278431,0.023529,0.52549,0.45098,0.72549,0.690196,0.941176,0.639216,0.560784,0.196078,0.364706,0.043137,0.494118,0.796078,0.113725,0.760784,0.729412,0.258824,0.290196,0.584314,0.67451,0.823529,0.905882,0.917647,0.070588,0.862745,0.345098,0.913725,0.937255,0.031373,0.215686,0.768627,0.333333,0.411765,0.423529,0.945098,0.721569,0.039216,0.792157,0.956863,0.266667,0.254902,0.047059,0.294118,0.658824,0.25098,1.0,0.984314,0.756863,0.027451,0.305882,0.835294,0.513725,0.360784,0.776471,0.611765,0.192157,0.866667,0.858824,0.592157,0.803922,0.141176,0.435294,0.588235,0.619608,0.341176,0.109804,0.356863,0.270588,0.737255,0.847059,0.05098,0.764706,0.019608,0.870588,0.933333,0.784314,0.54902,0.337255,0.631373,0.929412,0.231373,0.427451,0.078431,0.498039,0.968627,0.654902,0.12549,0.698039,0.015686,0.878431,0.713725,0.368627,0.431373,0.87451,0.403922,0.556863,0.443137,0.964706,0.909804,0.301961,0.035294,0.85098,0.882353,0.741176,0.380392,0.133333,0.470588,0.643137,0.282353,0.396078,0.980392,0.168627,0.14902,0.235294,0.670588,0.596078,0.733333,0.160784,0.376471,0.682353,0.545098,0.482353,0.745098,0.894118,0.188235,0.329412,0.439216,0.901961,0.0,0.6,0.388235,0.172549,0.090196,0.066667]};
	}
};
