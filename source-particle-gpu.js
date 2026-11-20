'use strict';

// Each transform-feedback vertex owns one persistent PCF particle slot.
globalThis.ReplayParticlesGPU=class {
	constructor(renderer,corners){
		this.r=renderer;this.g=renderer.gl;this.corners=corners;this.layers=new Map();this.systems=new Map();this.sheets=new Map();this.shaders=new Map();this.pointOps=new Map();this.high=new Map();
		for(const d of Object.values(renderer.map.particles || {})){
			this.pointOps.set(d.name,(d.operators || []).filter(o=>SourceParticles.operator(o)==='setcontrolpointpositions'));
			this.high.set(d.name,Math.max(0,...SourceParticles.usedPoints(d),...[...(d.initializers || []),...(d.operators || [])].map(o=>Number(o['control point'] ?? o['Control Point to offset positions from'] ?? 0))));
			const sprites=(d.renderers || []).filter(n=>['renderanimatedsprites','rendersprites','renderspritetrail'].includes(SourceParticles.operator(n)));
			const aggregate=(d.operators || []).some(o=>["setcontrolpointtoparticles'center",'movementmatchparticlevelocities'].includes(SourceParticles.operator(o)));
			this.layers.set(d.name,(sprites.length&&d.material?.texture||aggregate)&&(d.initial_particles||d.emitters?.length)?this.layer(d,sprites,aggregate):null);
		}
		if(Object.values(renderer.map.particles || {}).some(d=>d.constraints?.some(o=>SourceParticles.operator(o)==='collisionviatraces')))this.collision=this.geometry(renderer.map.collision || []);
	}
	// Threaded BVH: each node stores the texel after its subtree, so traces need no stack.
	geometry(groups){
		const triangles=[],data=[];
		for(const {vertices:v,brush} of groups)for(let j=0;j<v.length;j+=9)triangles.push({v,j,brush:brush?1:0});
		const node=(list)=>{
			const start=data.length,lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
			for(const {v,j} of list)for(let k=0;k<3;k++){lo[k]=Math.min(lo[k],v[j+k],v[j+k+3],v[j+k+6]);hi[k]=Math.max(hi[k],v[j+k],v[j+k+3],v[j+k+6]);}
			data.push(...lo,0,...hi,list.length<=12?list.length:0);
			if(list.length<=12){for(const {v,j,brush} of list)for(let p=j;p<j+9;p+=3)data.push(v[p],v[p+1],v[p+2],brush);}
			else{const span=hi.map((x,i)=>x-lo[i]),k=span.indexOf(Math.max(...span)),middle=list.length>>1;list.sort((a,b)=>(a.v[a.j+k]+a.v[a.j+k+3]+a.v[a.j+k+6])-(b.v[b.j+k]+b.v[b.j+k+3]+b.v[b.j+k+6]));node(list.slice(0,middle));node(list.slice(middle));}
			data[start+3]=data.length/4;
		};
		if(triangles.length)node(triangles);else data.push(0,0,0,0);
		const width=Math.min(2048,data.length/4),height=Math.ceil(data.length/(4*width)),flat=new Float32Array(width*height*4);flat.set(data);return this.texture(width,height,flat);
	}
	reduce(s,layer){
		const g=this.g;
		if(!this.reduction)this.reduction=this.r.program(`#version 300 es
precision highp float;layout(location=0)in float vertex;uniform highp sampler2D state;uniform vec3 offset;out vec4 result;
void main(){vec3 lo=vec3(1e30),hi=-lo,sum=vec3(0);float speed=0.,n=0.;for(int i=0;i<textureSize(state,0).y;i++){if(texelFetch(state,ivec2(6,i),0).w<.5)continue;vec3 p=texelFetch(state,ivec2(0,i),0).xyz,v=texelFetch(state,ivec2(1,i),0).xyz;lo=min(lo,p);hi=max(hi,p);sum+=v;speed+=length(v);n++;}result=vertex<.5?vec4((lo+hi)*.5+offset,n):vec4(sum/max(length(sum),.00001),speed/max(n,1.));gl_Position=vec4(0);}`,'#version 300 es\nprecision highp float;out vec4 c;void main(){c=vec4(0);}', ['result']);
		g.activeTexture(g.TEXTURE6);
		if(!s.stats){s.stateTex=this.texture(13,layer.count,null,false);s.stats=this.texture(2,1,null,false);s.result=g.createBuffer();g.bindBuffer(g.ARRAY_BUFFER,s.result);g.bufferData(g.ARRAY_BUFFER,32,g.DYNAMIC_COPY);g.bindBuffer(g.ARRAY_BUFFER,null);}
		const copy=(tex,buf,w,h)=>{g.bindTexture(g.TEXTURE_2D,tex);g.bindBuffer(g.PIXEL_UNPACK_BUFFER,buf);g.texSubImage2D(g.TEXTURE_2D,0,0,0,w,h,g.RGBA,g.FLOAT,0);g.bindBuffer(g.PIXEL_UNPACK_BUFFER,null);};
		g.bindVertexArray(this.r.particleVertexVao);copy(s.stateTex,s.buffers[s.side],13,layer.count);const p=this.reduction;g.useProgram(p);g.uniform1i(this.r.u(p,'state'),6);g.uniform3fv(this.r.u(p,'offset'),layer.centerOffset);
		g.bindBufferBase(g.TRANSFORM_FEEDBACK_BUFFER,0,s.result);g.beginTransformFeedback(g.POINTS);g.drawArrays(g.POINTS,0,2);g.endTransformFeedback();g.bindBufferBase(g.TRANSFORM_FEEDBACK_BUFFER,0,null);copy(s.stats,s.result,2,1);
	}
	texture(width,height,data,shared=true){
		const g=this.g,t=g.createTexture();if(shared)this.r.textures.push(t);g.bindTexture(g.TEXTURE_2D,t);
		g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MIN_FILTER,g.NEAREST);g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MAG_FILTER,g.NEAREST);
		g.texImage2D(g.TEXTURE_2D,0,g.RGBA32F,width,height,0,g.RGBA,g.FLOAT,data);return t;
	}
	sheet(image){
		if(this.sheets.has(image))return this.sheets.get(image);
		const sheets=Array.isArray(image.sheet)?image.sheet:[],w=1+2*Math.max(1,...sheets.map(s=>s.frames.length)),h=1+Math.max(0,...sheets.map(s=>s.id)),data=new Float32Array(w*h*4);
		for(const s of sheets){let at=s.id*w*4,time=0;data.set([s.frames.length,s.duration,+s.loop,0],at);at+=4;
			for(const f of s.frames){data.set(f.bounds[0],at);data.set([time,f.duration,0,0],at+4);time+=f.duration;at+=8;}}
		const t=this.texture(w,h,data);this.sheets.set(image,t);return t;
	}
	layer(d,sprites,aggregate){
		if(!this.noise){const n=SourceParticles.noiseTables(),a=new Float32Array(1024);for(let i=0;i<256;i++)a.set([n.a[i],n.b[i],n.c[i],n.impulse[i]],4*i);this.noise=this.texture(256,1,a);}
		const step=Math.max(1/60,Number(d['minimum simulation time step'] || 0)),life=SourceParticles.lifetime(d),decay=(d.operators || []).some(o=>['lifespandecay','alphafadeanddecay'].includes(SourceParticles.operator(o)));
		const count=Math.max(1,Math.min(d.max_particles ?? 1000,(d.initial_particles || 0)+(d.emitters || []).reduce((sum,e)=>sum+(SourceParticles.operator(e)==='emitinstantaneously'?(e.num_to_emit ?? 100):!decay||e['scale emission to used control points']?Infinity:Math.ceil((life+2*step)*(e.emission_rate ?? 100))),0)));
		const shader=ReplayParticlesGPU.shader(d,sprites[0] || {},count);let p=this.shaders.get(shader);
		if(!p){p=this.r.program(shader,'#version 300 es\nprecision highp float;out vec4 c;void main(){c=vec4(0);}',Array.from({length:13},(_,i)=>'o'+i));this.shaders.set(shader,p);}
		const v=d.material?.values || {},crop=String(v.$cropfactor || '').match(/[-+]?\d*\.?\d+/g)?.map(Number),rot=d.renderers?.find(n=>SourceParticles.operator(n)==='renderscreenvelocityrotate');
		return {p,atlas:this.sheet(d.material?.texture || this),step,life,decay,count,sprites,aggregate,lock:d.operators?.some(o=>SourceParticles.operator(o)==='movementlocktocontrolpoint'),centerOffset:d.operators?.find(o=>SourceParticles.operator(o)==="setcontrolpointtoparticles'center")?.['Center Offset'] || [0,0,0],
			draw:{material:d.material,cropX:crop?.[0] ?? 1,cropY:crop?.[1] ?? 1,velocityAngle:rot?Number(rot.forward_angle ?? -90)*Math.PI/180:100,
				sizes:[Number(v.$minsize ?? 0),Number(v.$maxsize ?? 20),Number(v.$startfadesize ?? 10),['$minsize','$maxsize','$startfadesize','$endfadesize'].some(k=>v[k]!==undefined)?Number(v.$endfadesize ?? 20):-1]}};
	}
	system(layer){
		const g=this.g,s={side:0,tick:null,buffers:[],sim:[],draw:[]},attribute=(i,n,stride,offset,divisor)=>{g.enableVertexAttribArray(i);g.vertexAttribPointer(i,n,g.FLOAT,false,stride,offset);g.vertexAttribDivisor(i,divisor);};
		for(let i=0;i<2;i++){
			const b=g.createBuffer();s.buffers.push(b);g.bindBuffer(g.ARRAY_BUFFER,b);g.bufferData(g.ARRAY_BUFFER,layer.count*208,g.DYNAMIC_COPY);
			let vao=g.createVertexArray();s.sim.push(vao);g.bindVertexArray(vao);for(let j=0;j<13;j++)attribute(j,4,208,16*j,0);
			vao=g.createVertexArray();s.draw.push(vao);g.bindVertexArray(vao);for(const [j,n,slot] of [[0,4,7],[2,4,8],[3,4,11],[4,4,9],[5,4,10],[6,3,1]])attribute(j,n,208,16*slot,1);
			g.bindBuffer(g.ARRAY_BUFFER,this.corners);attribute(1,2,8,0,0);
		}
		g.bindVertexArray(null);g.bindBuffer(g.ARRAY_BUFFER,null);return s;
	}
	free(s){const g=this.g;for(const b of s.buffers)g.deleteBuffer(b);for(const v of [...s.sim,...s.draw])g.deleteVertexArray(v);if(s.stats){g.deleteTexture(s.stateTex);g.deleteTexture(s.stats);g.deleteBuffer(s.result);}}
	dispose(){for(const s of this.systems.values())this.free(s);this.systems.clear();}
	controls(root,high,old){
		const g=this.g,boxes=root.hitboxes?.(1) || [],rows=Math.max(2,high+1,boxes.length),width=15;
		if(!this.controlData||this.controlData.length<rows*width*4)this.controlData=new Float32Array(rows*width*4);
		const data=this.controlData,matrices=[];for(let i=0;i<=Math.max(1,high);i++){const at=i*width*4,pt=root.point(i),m=Float32Array.from(root.basis(i));m.set(pt,12);matrices.push(m);data.set(pt,at);data.set(m,at+28);data.set(old?.[i] || m,at+44);}
		for(let i=0;i<boxes.length;i++){const at=i*width*4,b=boxes[i];data.set(b.world,at+4);data.set(b.mins,at+20);data.set(b.maxs,at+24);}
		g.activeTexture(g.TEXTURE0);
		if(!this.controlTex){this.controlTex=this.texture(width,rows,data);this.controlRows=rows;}
		else{g.bindTexture(g.TEXTURE_2D,this.controlTex);if(rows>this.controlRows){g.texImage2D(g.TEXTURE_2D,0,g.RGBA32F,width,rows,0,g.RGBA,g.FLOAT,data);this.controlRows=rows;}
			else g.texSubImage2D(g.TEXTURE_2D,0,0,0,width,rows,g.RGBA,g.FLOAT,data);}
		return {boxes:boxes.length,basis:root.basis(root.hitboxes?1:0),matrices};
	}
	prepare(effects){
		const out=[],seen=new Set(),defs=this.r.map.particles || {},g=this.g;let simulating=false,boundRoot,boundHigh=-1,controls;
		for(const effect of effects){
			const visit=(name,target,key,root,parentCenter,ancestors)=>{
				const d=defs[name];if(!d||target<0||ancestors.includes(name)||SourceParticles.usedPoints(d).some(i=>!root.resolved(i)&&i!==parentCenter?.cp))return;
				let high=Math.max(root.highest,this.high.get(name),parentCenter?.cp ?? 0);
				for(const op of this.pointOps.get(name))if(SourceParticles.strength(op,target)>0){
					const base=root,pts=new Map(),cp=op['Control Point to offset positions from'] || 0,m=Float32Array.from(root.basis(cp));m.set(root.point(cp),12);
					for(const [i,w] of ['First','Second','Third','Fourth'].entries()){const offset=op[w+' Control Point Location'];if(!offset)continue;const j=op[w+' Control Point Number'] ?? i+1;pts.set(j,op['Set positions in world space']?offset:ReplayRenderer.point(m,offset));high=Math.max(high,j);}
					root={...base,point:i=>pts.get(i) || base.point(i),resolved:i=>pts.has(i)||base.resolved(i)};
				}
				const layer=this.layers.get(name);
				if(layer){const tick=Math.floor(target/layer.step+1.e-5);let s=this.systems.get(key);
					if(!s){this.systems.set(key,s=this.system(layer));}seen.add(key);
					const reset=s.tick===null||tick<s.tick||(tick-s.tick)*layer.step>1;
					if(reset||s.tick!==tick){
						if(!simulating){g.enable(g.RASTERIZER_DISCARD);simulating=true;}
						if(boundRoot!==root||boundHigh<high||layer.lock){controls=this.controls(root,high,reset?null:s.matrices);boundRoot=root;boundHigh=high;}if(layer.lock)s.matrices=controls.matrices;
						const p=layer.p,u=k=>this.r.u(p,k),from=reset?Math.max(0,tick-(layer.decay?Math.ceil(layer.life/layer.step):1)):s.tick;
						g.useProgram(p);g.uniform1i(u('dynamicRoot'),+!!root.dynamic);g.uniform1i(u('seed'),effect.seed);
						g.uniform1i(u('highest'),root.highest);g.uniform1i(u('boxCount'),controls.boxes);g.uniform1i(u('stopped'),+!!root.stopped);g.uniformMatrix4fv(u('basis'),false,controls.basis);
						g.uniform1i(u('controls'),0);g.activeTexture(g.TEXTURE1);g.bindTexture(g.TEXTURE_2D,layer.atlas);g.uniform1i(u('atlas'),1);
						g.activeTexture(g.TEXTURE2);g.bindTexture(g.TEXTURE_2D,this.noise);g.uniform1i(u('noiseTex'),2);
						g.activeTexture(g.TEXTURE3);g.bindTexture(g.TEXTURE_2D,this.collision || this.noise);g.uniform1i(u('geometry'),3);
						g.activeTexture(g.TEXTURE4);g.bindTexture(g.TEXTURE_2D,parentCenter?.texture || this.noise);g.uniform1i(u('parentStats'),4);g.uniform1i(u('centerIndex'),parentCenter?.cp ?? -1);
						g.uniform1i(u('stats'),5);
						// Cross-particle operators consume the preceding step's reduction even after a seek.
						let at=from;do{
							g.useProgram(p);const end=layer.aggregate?Math.min(tick,at+1):tick;
							g.uniform1i(u('resetState'),Number(reset&&at===from));g.uniform1i(u('steps'),end-at);g.uniform1f(u('startTime'),at*layer.step);
							g.activeTexture(g.TEXTURE5);g.bindTexture(g.TEXTURE_2D,s.stats || this.noise);g.uniform1i(u('hasStats'),Number(!!s.stats&&!(reset&&at===from)));
							g.bindVertexArray(s.sim[s.side]);g.bindBufferBase(g.TRANSFORM_FEEDBACK_BUFFER,0,s.buffers[1-s.side]);g.beginTransformFeedback(g.POINTS);g.drawArrays(g.POINTS,0,layer.count);g.endTransformFeedback();
							g.bindBufferBase(g.TRANSFORM_FEEDBACK_BUFFER,0,null);s.side=1-s.side;if(layer.aggregate)this.reduce(s,layer);at=end;
						}while(at<tick);s.tick=tick;
					}
					for(const sprite of layer.sprites){const min=sprite['Visibility input distance minimum'] ?? 0,max=sprite['Visibility input distance maximum'] ?? 0,pt=root.point(sprite['Visibility Proxy Input Control Point Number'] ?? 0),t=max>min?SourceParticles.clamp(Math.hypot(...pt.map((v,k)=>v-root.visibilityOrigin[k]))/(max-min)-min/(max-min)):1,visibility=max>min?(sprite['Visibility Alpha Scale minimum'] ?? 0)*(1-t)+(sprite['Visibility Alpha Scale maximum'] ?? 1)*t:1;
						if(visibility>0)out.push({...layer.draw,particleVao:s.draw[s.side],instanceCount:layer.count,sky:root.sky,eye:root.eye,visibility,trail:SourceParticles.operator(sprite)==='renderspritetrail'?[sprite['min length'] || 0,sprite['max length'] ?? 2000]:null});}
					if(s.stats){const op=d.operators.find(o=>SourceParticles.operator(o)==="setcontrolpointtoparticles'center");if(op)parentCenter={cp:op['Control Point Number to Set'] ?? 1,texture:s.stats};}
				}
				for(const [i,c] of (d.children || []).entries())visit(c.name,target-c.delay,key+'/'+i,root,parentCenter,[...ancestors,name]);
			};
			visit(effect.name,effect.target,effect.key,effect.root,null,[]);
		}
		if(simulating){g.disable(g.RASTERIZER_DISCARD);g.bindVertexArray(null);g.activeTexture(g.TEXTURE0);}
		for(const [key,s] of this.systems)if(!seen.has(key)){this.free(s);this.systems.delete(key);}
		return out;
	}
	static shader(d,sprite,count){
		const f=x=>{const s=String(Number(x));return /[.e]/i.test(s)?s:s+'.0';},v=(x,k=0)=>`vec3(${[0,1,2].map(i=>f(x?.[i] ?? k)).join(',')})`,num=(o,k,b)=>f(o[k] ?? b);
		const strength=(o,t)=>`strength(${t},vec4(${['operator start fadein','operator end fadein','operator start fadeout','operator end fadeout'].map(k=>num(o,k,0))}))`;
		const remap=(x,a,b)=>`sat((${x}-${f(a)})/${f(b-a || 1)})`.replaceAll('--','- -');
		const init=(o)=>{
			const type=SourceParticles.operator(o),n=(k,b)=>num(o,k,b),rng=(a,b,p=1)=>`mix(${f(a)},${f(b)},pow(rnd(),${f(p)}))`,range=(key,a,b)=>rng(o[key+'_min'] ?? a,o[key+'_max'] ?? b,o[key+'_random_exponent'] ?? 1);
			const out=SourceParticles.field(o['output field'] ?? 3),scale=o['output is scalar of initial random range']?'*=':'=',gate=`born>=${n('emitter lifetime start time (seconds)',-1)}&&(${n('emitter lifetime end time (seconds)',-1)}<0.||born<${n('emitter lifetime end time (seconds)',-1)})`;
			const input=SourceParticles.field(o['input field'] ?? 8) || 'born',t=remap(input,o['input minimum'] ?? 0,o['input maximum'] ?? 1);
			switch(type){
			case 'lifetimerandom':return `life=${range('lifetime',1,1)};`;
			case 'radiusrandom':return `radius=${range('radius',1,1)};`;
			case 'alpharandom':return `alpha=${range('alpha',255,255)}/255.;`;
			case 'rotationrandom':return `rotation=radians(${n('rotation_initial',0)}+${rng(o.rotation_offset_min ?? 0,o.rotation_offset_max ?? 360,o.rotation_random_exponent ?? 1)});`;
			case 'rotationspeedrandom':return `rotationSpeed=radians(${range('rotation_speed',0,0)});`;
			case 'rotationyawrandom':return `yaw=radians(${n('yaw_initial',0)}+${rng(o.yaw_offset_min ?? 0,o.yaw_offset_max ?? 360,o.yaw_random_exponent ?? 1)});`;
			case 'positionwithinboxrandom':case 'positionwithinbox':return `pos+=mix(${v(o.min)},${v(o.max)},rand3());`;
			case 'velocityrandom':return `vel+=mix(${v(o['min velocity'])},${v(o['max velocity'])},rand3());`;
			case 'rotationyawfliprandom':return `if(rnd()<${n('Flip Percentage',.5)})yaw+=PI;`;
			case 'colorrandom':return `color=mix(${v(o.color1,255)},${v(o.color2 || o.color1,255)},rnd())/255.;`;
			case 'sequencerandom':return `sequence=floor(${rng(o.sequence_min ?? 0,(o.sequence_max ?? 0)+1)});if(fps>0.&&meta(sequence).x>0.)life=meta(sequence).y/fps;`;
			case 'lifetimefromsequence':return `fps=${n('Frames Per Second',30)};if(meta(sequence).x>0.)life=meta(sequence).y/fps;`;
			case 'positiononmodelrandom':{const bias=o['direction bias'],scale=n('hitbox scale',1);return `pos=cp(${o.control_point_number || 0});if(boxCount>0){float best=-1.e30;for(int trial=0;trial<${bias?.some(x=>x!==0)?5:1};trial++){int j=min(boxCount-1,int(rnd()*float(boxCount)));vec3 uvw=mix(vec3(1.-${scale}),vec3(${scale}),rand3()),pt=box(j,uvw);float score=72.*rnd()+dot(pt-cp(${o.control_point_number || 0}),${v(bias)});if(score>best){best=score;anchor=pt;pos=pt;hit=vec4(uvw,float(j));}}}`;}
			case 'positionwithinsphere':case 'positionwithinsphererandom':{const growth=o['randomly distribution growth time'],cp=o.control_point_number || 0;return `int j=${cp};${o['randomly distribute to highest supplied Control Point']?`if(highest>j)j+=int(rnd()*(floor(float(highest-j)*${growth?`sat(born/${f(growth)})`:'1.'})+1.));`:''}mat4 basis=cm(j,7);
				float z=2.*rnd()-1.,a=rnd()*2.*PI;vec3 dir=vec3(sqrt(max(0.,1.-z*z))*vec2(cos(a),sin(a)),z);dir=mix(dir,abs(dir),${v(o.distance_bias_absolute_value)})*${v(o.distance_bias,1)};dir/=max(.00001,length(dir));vec3 ofs=dir*mix(${n('distance_min',0)},${n('distance_max',0)},pow(rnd(),1./3.));pos=cp(j)+${o['bias in local system']?'mat3(basis)*':''}ofs;vel+=dir*${range('speed',0,0)}+mat3(basis)*mix(${v(o.speed_in_local_coordinate_system_min)},${v(o.speed_in_local_coordinate_system_max)},rand3());`;}
			case 'positionoffsetrandom':case 'positionmodifyoffsetrandom':return `pos+=${o['offset in local space 0/1']?`mat3(cm(${o.control_point_number || 0},7))*`:''}mix(${v(o['offset min'] || o.min)},${v(o['offset max'] || o.max)},rand3())${o['offset proportional to radius 0/1']?'*radius':''};`;
			case 'positionmodifywarprandom':{const dur=o['warp transition time (treats min/max as start/end sizes)'];return `vec3 w=${dur?`vec3(${remap('born',o['warp transition start time'] || 0,(o['warp transition start time'] || 0)+dur)})`:'rand3()'},c=cp(${o.control_point_number || 0});pos=c+(pos-c)*mix(${v(o['warp min'],1)},${v(o['warp max'],1)},${o['reverse warp (0/1)']?'1.-w':'w'});`;}
			case 'velocitynoise':return `vec3 coord=(born+${n('Time Coordinate Offset',0)})*${n('Time Noise Coordinate Scale',1)}+(pos+${v(o['Spatial Coordinate Offset'])})*${n('Spatial Noise Coordinate Scale',.01)},q=vec3(noise3(coord),noise3(coord+vec3(100000.5,300000.25,9000000.75)),noise3(coord+vec3(110000.25,310000.75,9100000.5)));q=mix((q+1.)*.5,abs(q),${v(o['Absolute Value'])});q=mix(q,1.-q,${v(o['Invert Abs Value'])});vel+=${o['Apply Velocity in Local Space (0/1)']?'mat3(basis)*':''}mix(${v(o['output minimum'])},${v(o['output maximum'],1)},q);`;
			case 'remapnoisetoscalar':case 'lifetimepreagenoise':{if(!out&&type==='remapnoisetoscalar')return '';const q=`noise3((born+${n('time coordinate offset',0)})*${n('time noise coordinate scale',1)}+(pos+${v(o['spatial coordinate offset'])})*${n('spatial noise coordinate scale',.01)})`,val=o['absolute value']?`abs(${q})`:`(1.+${q})*.5`;return `float q=${o['invert absolute value']?'1.-':''}${val};`+(type==='lifetimepreagenoise'?`born-=life*mix(${n('start age minimum',0)},${n('start age maximum',1)},q);`:`${out}${scale}mix(${n('output minimum',0)},${n('output maximum',1)},q)${['rotation','rotationSpeed','yaw'].includes(out)?'*(PI/180.)':''};`);}
			case 'remapinitialdistancetocontrolpointtoscalar':case 'remapinitialscalar':{if(!out)return '';const dist=type!=='remapinitialscalar',x=dist?`distance(pos,cp(${o['control point'] || 0}))`:input,lo=o[dist?'distance minimum':'input minimum'] ?? 0,hi=o[dist?'distance maximum':'input maximum'] ?? (dist?128:1);let a=o['output minimum'] ?? 0,b=o['output maximum'] ?? 1;if(out==='alpha'){a=SourceParticles.clamp(a);b=SourceParticles.clamp(b);}return `if(${dist?'true':gate}${o[dist?'only active within specified distance':'only active within specified input range']?`&&${x}>=${f(lo)}&&${x}<=${f(hi)}`:''})${out}${scale}mix(${f(a)},${f(b)},${remap(x,lo,hi)});`;}
			case 'remapscalartovector':return `if(${gate})${o['output field']===6?'color':'pos'}${scale}mix(${v(o['output minimum'])},${v(o['output maximum'],1)},${t});`;
			default:return '';
			}
		};
		const motion=[],appearance=[];
		for(const [i,o] of (d.operators || []).entries()){
			const kind=SourceParticles.operator(o),n=(k,b)=>num(o,k,b),weight=strength(o,'now'),rand=(key,sample,a,b,exp=1)=>`mix(${n(key+' min',a)},${n(key+' max',b)},pow(hash(${i*32+sample}u),${f(exp)}))`;let code='',draw=false;
			if(kind==='movementbasic'||kind==='basicmovement'){const forces=(d.forces || []).map((node,j)=>{
				const op=SourceParticles.operator(node),w=strength(node,'now');if(op==='pulltowardscontrolpoint')return `{vec3 delta=cp(${node['control point number'] || 0})-pos;float l=length(delta);if(l>1.e-6)acc+=delta*(${num(node,'amount of force',0)}*${w})*pow(l,${f(Math.trunc(-4*(node['falloff power'] ?? 2))/4-1)});}`;
				if(op==='twistaroundaxis')return `{vec3 axis=unit(${node['object local space axis 0/1']?'mat3(cm(0,7))*':''}${v(node['twist axis'] || [0,0,1])}),off=unit(pos-cp(0));acc+=cross(unit(off*(1.-dot(off,axis))),axis)*${num(node,'amount of force',0)}*${w};}`;
				return op==='randomforce'?`acc+=mix(${v(node['min force'])},${v(node['max force'])},vec3(hash(uint(round(now/DT))*31u+${j*3}u),hash(uint(round(now/DT))*31u+${j*3+1}u),hash(uint(round(now/DT))*31u+${j*3+2}u)))*${w};`:'';}).join('');
				const constraints=(d.constraints || []).map(node=>{const op=SourceParticles.operator(node),cp=node['control point number'] || 0,off=v(node['offset of center']);
					if(op==='constraindistancetocontrolpoint')return `{vec3 center=${node['global center point']?off:`cp(${cp})+mat3(cm(${cp},7))*${off}`},delta=pos-center;float len=length(delta);if(len>1.e-8){pos=center+delta*(clamp(len,${num(node,'minimum distance',0)},${num(node,'maximum distance',100)})/len);vel=(pos-prev)/DT;}}`;
					if(op!=='collisionviatraces')return '';const bounce=num(node,'amount of bounce',0),slide=num(node,'amount of slide',0);return `{vec3 delta=pos-prev;vec4 hit=traceWorld(prev,delta+unit(delta)*radius*${num(node,'radius scale',1)},${!!node['brush only']});if(hit.w<1.){${node['kill particle on collision']?'life=0.;alive=false;':`vec3 move=reflect(unit(delta),hit.xyz)*${bounce}+(delta-dot(delta,hit.xyz)*hit.xyz)*${slide};pos=prev+delta*hit.w+move*(1.-hit.w);vel=${node['amount of bounce']||node['amount of slide']?'move':'(pos-prev)'}/DT;`}}}`;}).join('');
				code=`vec3 acc=${v(o.gravity)};${forces}vel=vel*${f(Math.pow(Math.max(0,1-(o.drag || 0)),30*Math.max(1/60,Number(d['minimum simulation time step'] || 0))))}+acc*DT;prev=pos;pos+=vel*DT;${constraints}`;}
			else if(kind==='movementlocktobone'){const a=o['lifetime fade start'] ?? 0,b=o['lifetime fade end'] ?? 1;code=`if(hit.w>=0.&&int(hit.w)<boxCount){vec3 pt=box(int(hit.w),hit.xyz);float w=${a===b?`float(frac<${f(b)})`:`1.-${remap('frac',a,b)}`};pos+=(pt-anchor)*w*weight;anchor=pt;}`;}
			else if(kind==='remapdistancetocontrolpointtoscalar'){const field=SourceParticles.field(o['output field'] ?? 3),lo=o['distance minimum'] ?? 0,hi=o['distance maximum'] ?? 128,base={life:'baseLife',radius:'baseRadius',alpha:'baseAlpha'}[field];if(field)code=`float dist=distance(pos,cp(${o['control point'] || 0}));${o['only active within specified distance']?`if(dist>=${f(lo)}&&dist<=${f(hi)})`:''}${field}=mix(${field},mix(${n('output minimum',0)},${n('output maximum',1)},${remap('dist',lo,hi)})${o['output is scalar of initial random range']&&base?'*'+base:''},weight);`;}
			else if(kind==='oscillatescalar'){const key=SourceParticles.field(o['oscillation field'] ?? 7);if(key)code=`${key}+=weight*DT*${rand('oscillation rate',0,0,0)}*sin(PI*(${o['proportional 0/1']===false?'now':'frac'}*${n('oscillation multiplier',2)}*${rand('oscillation frequency',1,1,1)}+${n('oscillation start phase',.5)}));${key.startsWith('alpha')?`${key}=sat(${key});`:''}`;}
			else if(kind==='oscillatevector'){const key=({0:'pos',2:'prev',6:'color'})[o['oscillation field'] ?? 0],vecRand=(name,j,b)=>`mix(${v(o[name+' min'],b)},${v(o[name+' max'],b)},vec3(${[0,1,2].map(k=>`hash(${i*32+j+k}u)`)}))`;if(key)code=`float clock=${o['start/end proportional']===false?'now-born':'frac'};if(clock>=${rand('start time',11,0,0)}&&clock<${rand('end time',12,1,1)}){vec3 frequency=${vecRand('oscillation frequency',3,1)},angle=${o['proportional 0/1']===false?`frequency*(now*${n('oscillation multiplier',2)}+${n('oscillation start phase',.5)})`:`frac*${n('oscillation multiplier',2)}*frequency+${n('oscillation start phase',.5)}`},x=fract(abs(angle));${key}+=${vecRand('oscillation rate',0,0)}*DT*weight*x*(4.-4.*x)*sign(angle)*(1.-2.*mod(floor(abs(angle)),2.));${key==='color'?'color=clamp(color,0.,1.);':'vel=(pos-prev)/DT;'}}`;}
			else if(kind==='movementmaxvelocity')code=`vel=unit(vel)*min(length(vel),${n('Maximum Velocity',0)});pos=prev+vel*DT;`;
			else if(kind==='movementmatchparticlevelocities')code=`if(hasStats){vec4 avg=texelFetch(stats,ivec2(1,0),0);if(length(avg.xyz)>0.){vel=unit(mix(unit(vel),avg.xyz,${n('Direction Matching Strength',.25)}))*mix(length(vel),avg.w,${n('Speed Matching Strength',.25)});pos=prev+vel*DT;}}`;
			else if(kind==='movementlocktocontrolpoint'){const cp=o.control_point_number || 0,fade=(k,j)=>`mix(${n(k+'_fadeout_min',1)},${n(k+'_fadeout_max',1)},pow(hash(uint(round(now/DT))*53u+${i*2+j}u),${f(Math.trunc((o[k+'_fadeout_exponent'] ?? 1)*4)/4)}))`;
				code=`if(k==0&&!resetState){mat4 a=cm(${cp},7),b=cm(${cp},11);float s=${fade('start',9)},e=${fade('end',10)},lock=${(o.start_fadeout_min ?? 1)>=1?'1.':'1.-sat((frac-s)/max(.00001,e-s))'},w=sat((now-born)/DT)*lock*weight;vec3 move=${o['lock rotation']?'(a*inverse(b)*vec4(pos,1)).xyz-pos':'a[3].xyz-b[3].xyz'};${o['distance fade range']>0?`w*=1.-curve(distance(pos+move*w,a[3].xyz)/${n('distance fade range',1)},false,.2);`:''}pos+=move*w;prev+=move*w;}`;}
			else if(kind==='rotationbasic'||kind==='rotationmovement')code='rotation+=rotationSpeed*DT*weight;';
			else if(kind==='rotationspinroll'||kind==='rotationspin')code=`rotation+=DT*weight*max(${f(Math.abs(o.spin_rate_min || 0)*Math.PI*Math.PI/90)},${f((o.spin_rate_degrees || 0)*Math.PI*Math.PI/90)}*${o.spin_stop_time>0?`max(0.,1.-frac/${n('spin_stop_time',1)})`:'1.'});`;
			else if(kind==='alphafadeanddecay'||kind==='alphafade'){draw=true;code=`if(frac<${n('end_fade_in_time',0)})opacity=baseAlpha*curve(${remap('frac',o.start_fade_in_time || 0,o.end_fade_in_time || 0)},true,.5);else if(frac>${n('start_fade_out_time',1)})opacity=baseAlpha*(1.-curve(${remap('frac',o.start_fade_out_time ?? 1,o.end_fade_out_time ?? 1)},true,.5));`;}
			else if(kind==='radiusscale'){const a=o.start_time ?? 0,b=o.end_time ?? 1;draw=true;code=`if(frac>=${f(a)}&&frac<=${f(b)})displayR=radius*mix(${n('radius_start_scale',1)},${n('radius_end_scale',1)},curve(${remap('frac',a,b)},${!!o.ease_in_and_out},${n('scale_bias',.5)}));`;}
			else if(kind==='colorfade'){draw=true;code=`rgb=mix(color,${o.color_fade?v(o.color_fade)+'/255.':'color'},${remap('frac',o.fade_start_time ?? 0,o.fade_end_time ?? 1)});`;}
			else if(kind==='alphafadeinrandom'||kind==='alphafadeoutrandom'){const fadeIn=kind==='alphafadeinrandom',key=fadeIn?'fade in time':'fade out time';draw=true;code=`float dur=${rand(key,20,.25,.25,o[key+' exponent'] ?? 1)},t=${o['proportional 0/1']===false?'age':'frac'},end=${o['proportional 0/1']===false?'life':'1.'};`+(fadeIn?'if(t<dur)opacity=alpha*curve(t/max(dur,.00001),true,.5);':`if(t>end-dur)opacity=alpha*(1.-curve((t-end+dur)/max(dur,.00001),${o['ease in and out']!==false},${n('fade bias',.5)}));`);}
			if(code)(draw?appearance:motion).push(`{float weight=${weight};if(weight>0.){${code}}}`);
		}
		const step=Math.max(1/60,Number(d['minimum simulation time step'] || 0)),decay=(d.operators || []).some(o=>['lifespandecay','alphafadeanddecay'].includes(SourceParticles.operator(o))),schedule=[];
		if(d.initial_particles)schedule.push(`if(k<0&&(${!decay}||startTime==0.)){submitBirth(${d.initial_particles}.,0.,0.,0.,0.,total,spawn,birth,index);}`);
		for(const [i,e] of (d.emitters || []).entries()){
			const start=Math.max(e.emission_start_time || 0,e['operator start fadein'] || 0),duration=e.emission_duration,b=f(start),op=SourceParticles.operator(e),base=f((i+1)*104729);
			if(op==='emitinstantaneously')schedule.push(`if(now>=${b}&&(before<${b}||k<0&&(${!decay}||now==${b})))submitBirth(${num(e,'num_to_emit',100)},${b},0.,${base},0.,total,spawn,birth,index);`);
			if(op==='emitcontinuously')schedule.push(`{float rate=${num(e,'emission_rate',100)},end=${duration>0?`min(now,${f(start+duration)})`:'now'},begin=max(${b},before),high=float(highest)*${num(e,'scale emission to used control points',0)};
				if(dynamicRoot){rate*=${strength(e,'now')}*(high>0.?high:1.);if(!stopped&&rate>0.&&end>begin){float extra=(end-begin)*rate;submitBirth(extra,begin,rate,${base}+floor(total),fract(total),total,spawn,birth,index);}}
				else if(rate>0.){float last=floor(max(0.,end-${b})*rate+.00001),first=floor(max(0.,min(before,end)-${b})*rate+.00001);if(k<0){${decay?'total+=first;':'first=0.;'}}submitBirth(last-first,${b}+first/rate,rate,${base}+first,0.,total,spawn,birth,index);}}`);
		}
		return `#version 300 es
precision highp float;precision highp int;precision highp sampler2D;
${Array.from({length:13},(_,i)=>`layout(location=${i})in vec4 a${i};out vec4 o${i};`).join('\n')}
uniform int steps,seed,highest,boxCount,centerIndex;uniform bool stopped,resetState,dynamicRoot,hasStats;uniform float startTime;uniform mat4 basis;uniform sampler2D controls,atlas,noiseTex,geometry,parentStats,stats;
const float DT=${f(step)},PI=3.14159265;uint id,sampleIndex;
float sat(float x){return clamp(x,0.,1.);}float curve(float x,bool ease,float bias){float t=sat(x);return ease?t*t*(3.-2.*t):t/((1./max(.00001,bias)-2.)*(1.-t)+1.);}
float strength(float t,vec4 v){if(t<v.x)return 0.;if(t<v.y)return (t-v.x)/(v.y-v.x);if(v.w>0.&&t>=v.z)return max(0.,(v.w-t)/(v.w==v.z?1.:v.w-v.z));return 1.;}
float hash(uint s){uint x=id*1664525u+s*1013904223u;x^=x<<13;x^=x>>17;x^=x<<5;return float(x>>8)*(1./16777216.);}
float rnd(){return hash(++sampleIndex);}vec3 rand3(){float x=rnd(),y=rnd(),z=rnd();return vec3(x,y,z);}
vec3 unit(vec3 v){return v/max(length(v),1.e-12);}vec4 ct(int x,int y){return texelFetch(controls,ivec2(x,clamp(y,0,textureSize(controls,0).y-1)),0);}mat4 cm(int j,int x){return mat4(ct(x,j),ct(x+1,j),ct(x+2,j),ct(x+3,j));}
vec3 cp(int i){if(i==centerIndex){vec4 pt=texelFetch(parentStats,ivec2(0),0);if(pt.w>0.)return pt.xyz;}return ct(0,i).xyz;}vec3 box(int j,vec3 uvw){return (cm(j,1)*vec4(mix(ct(5,j).xyz,ct(6,j).xyz,uvw),1)).xyz;}
vec4 geom(int i){int width=textureSize(geometry,0).x;return texelFetch(geometry,ivec2(i%width,i/width),0);}
vec4 traceWorld(vec3 pos,vec3 dir,bool brush){vec4 hit=vec4(0,0,0,1);if(dot(dir,dir)<1.e-12)return hit;int i=0,end=int(geom(0).w);vec3 inv=1./mix(dir,vec3(1.e-16),lessThan(abs(dir),vec3(1.e-16)));
while(i<end){vec4 a=geom(i),b=geom(i+1);vec3 p=(a.xyz-pos)*inv,q=(b.xyz-pos)*inv,lo=min(p,q),hi=max(p,q);if(max(0.,max(max(lo.x,lo.y),lo.z))>min(hit.w,min(min(hi.x,hi.y),hi.z))){i=int(a.w);continue;}i+=2;for(int n=0;n<int(b.w);n++,i+=3){vec4 v=geom(i);if(brush&&v.w<.5)continue;vec3 ab=geom(i+1).xyz-v.xyz,ac=geom(i+2).xyz-v.xyz,h=cross(dir,ac);float det=dot(ab,h);if(abs(det)<1.e-8)continue;vec3 t=pos-v.xyz,r=cross(t,ab);float u=dot(t,h)/det,w=dot(dir,r)/det,f=dot(ac,r)/det;if(u>=0.&&w>=0.&&u+w<=1.&&f>=0.&&f<hit.w){vec3 normal=unit(cross(ab,ac));hit=vec4(dot(normal,dir)>0.?-normal:normal,f);}}}return hit;}
void submitBirth(float amount,float begin,float rate,float base,float fraction,inout float total,inout bool spawn,inout float birth,inout float index){float next=total+amount;int first=int(floor(total)),last=int(floor(next)),slot=gl_VertexID,j=last-((last-1-slot+${count})%${count});if(j>first&&j<=last){spawn=true;float n=float(j-first);birth=begin+(rate>0.?(n-fraction)/rate:0.);index=base+n;}total=next;}
vec4 meta(float seq){int row=int(seq);return row<0||row>=textureSize(atlas,0).y?vec4(0):texelFetch(atlas,ivec2(0,row),0);}
vec4 table(int i){return texelFetch(noiseTex,ivec2(i&255,0),0);}float lattice(ivec3 i){return table(int(table(i.z+int(table(i.y+int(table(i.x).x)).y)).z)).w;}
float noise3(vec3 p){ivec3 bits=floatBitsToInt(p+32768.)&65535,i=bits>>8;vec3 q=vec3(bits&255)/256.;vec4 x=mix(vec4(lattice(i),lattice(i+ivec3(0,1,0)),lattice(i+ivec3(0,0,1)),lattice(i+ivec3(0,1,1))),vec4(lattice(i+ivec3(1,0,0)),lattice(i+ivec3(1,1,0)),lattice(i+ivec3(1,0,1)),lattice(i+1)),q.x);return 2.*(mix(mix(x.x,x.y,q.y),mix(x.z,x.w,q.y),q.z)-.5);}
void main(){vec3 pos=a0.xyz,vel=a1.xyz,color=a2.xyz,anchor=a5.xyz;float born=a0.w,life=a1.w,radius=a2.w,serial=a3.x,rotation=a3.y,yaw=a3.z,sequence=a3.w,baseLife=a5.w,alpha=a6.x,alpha2=a6.y,total=resetState?0.:a6.z,rotationSpeed=a12.x,trail=a12.y,baseRadius=a12.z,baseAlpha=a12.w;bool alive=!resetState&&a6.w>.5;vec4 hit=a4;float now=startTime;
for(int k=resetState?-1:0;k<steps;k++){now=startTime+float(k+1)*DT;float before=k<0?now:startTime+float(k)*DT,birth=0.,index=0.;bool spawn=false;
${schedule.join('\n')}
if(spawn&&(!alive${decay?'||now-born>=life':''})){
serial=index;id=uint(seed)+uint(serial)*7919u;sampleIndex=0u;born=birth;pos=cp(0);vel=vec3(0);radius=${num(d,'radius',5)};color=${v(d.color,255)}/255.;alpha=${f((d.color?.[3] ?? 255)/255)};alpha2=1.;life=1.;rotation=${num(d,'rotation',0)};rotationSpeed=${num(d,'rotation_speed',0)};trail=.1;sequence=${num(d,'sequence_number',0)};yaw=0.;float fps=0.;hit=vec4(0,0,0,-1);anchor=pos;
${(d.initializers || []).map(o=>{const code=init(o);return code?`if(${strength(o,'born')}>0.){${code}}`:'';}).join('\n')}
baseLife=life;baseRadius=radius;baseAlpha=alpha;alive=true;}if(!alive||k<0)continue;id=uint(seed)+uint(serial)*7919u;
if(life<=0.${decay?'||now-born>=life':''}){alive=false;continue;}float frac=(now-born)/life;vec3 prev=pos-vel*DT;${motion.join('\n')}
}
o0=vec4(pos,born);o1=vec4(vel,life);o2=vec4(color,radius);o3=vec4(serial,rotation,yaw,sequence);o4=hit;o5=vec4(anchor,baseLife);o6=vec4(alpha,alpha2,total,float(alive));
o7=vec4(0);o8=vec4(0);o9=vec4(0,0,1,1);o10=o9;o11=vec4(rotation,yaw,0,0);o12=vec4(rotationSpeed,trail,baseRadius,baseAlpha);
if(alive&&life>0.){id=uint(seed)+uint(serial)*7919u;float age=now-born,frac=age/life,displayR=radius,opacity=alpha;vec3 rgb=color;${appearance.join('\n')}
o11.w=trail*${sprite['length fade in time']>0?`sat(age/${num(sprite,'length fade in time',1)})`:'1.'};
o7=vec4(pos,displayR);o8=vec4(rgb,opacity*alpha2);vec4 info=meta(sequence);int size=int(info.x),row=int(sequence);if(size>0&&info.y>0.){
float t=${sprite.animation_fit_lifetime?'frac*info.y':`age*${num(sprite,'animation rate',SourceParticles.operator(sprite)==='renderspritetrail'?.1:1)}${sprite['use animation rate as FPS']?'':'*(dynamicRoot?info.y:1.)'}`};t=info.z>.5?min(t,info.y):mod(t,info.y);
int lo=0,hi=size-1;while(lo<hi){int mid=(lo+hi)/2;vec2 timing=texelFetch(atlas,ivec2(2+2*mid,row),0).xy;if(t<timing.x+timing.y)hi=mid;else lo=mid+1;}int nx=lo+1<size?lo+1:(info.z>.5?lo:0);
o9=texelFetch(atlas,ivec2(1+2*lo,row),0);o10=texelFetch(atlas,ivec2(1+2*nx,row),0);vec2 timing=texelFetch(atlas,ivec2(2+2*lo,row),0).xy;o11.z=sat((t-timing.x)/max(.00001,timing.y));}}
gl_Position=vec4(0,0,0,1);}`;
	}
};
