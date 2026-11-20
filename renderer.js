'use strict';
// Stylised (toon) deferred-ish renderer for the replay viewer.
//
// Frame: cached world shadow + per-frame actor shadows -> main pass (MRT: HDR colour,
// glow, normal/mask) with frustum-culled world chunks -> half-res AO -> bloom chain
// -> composite (ink outlines, AO, fog, sky) -> tone map -> diagnostics and GPU trails
// -> FXAA to the canvas.
globalThis.ReplayRenderer = class {
	constructor(gl, map, models, options = {}) {
		this.gl = gl; this.models = models; this.options = options;
		this.buffers = []; this.textures = []; this.textureImages = new Set(); this.programs = []; this.vaos = []; this.targets = [];
		this.meshes = new Map(); this.trails = new Map(); this.uniformCache = new Map(); this.width = 0; this.height = 0;
		this.materialProfiles = new WeakMap(); this.fixedProfiles = new Map();
		this.s3tc = gl.getExtension('WEBGL_compressed_texture_s3tc'); this.hdr = !!gl.getExtension('EXT_color_buffer_float');
		gl.getExtension('OES_texture_float_linear');
		this.map = map; this.environment = map.environment; this.skyScale = map.sky?.scale || 1;
		this.sunDir = ReplayRenderer.normalize([-.35, -.45, .82]);
		this.shadowSize = Math.min(4096, gl.getParameter(gl.MAX_TEXTURE_SIZE)); this.shadowKey = null; this.boneRows = 0;
		this.exposureFrames = 0; this.exposureClock = null;
		this.compile();
		this.white = this.texture({width:1, height:1, data:new Uint8Array([255,255,255,255]), flags:0});
		this.black = this.texture({width:1, height:1, data:new Uint8Array([0,0,0,255]), flags:0});
		this.flashlightCookie = map.flashlight ? this.texture(map.flashlight) : this.black;
		this.flashlightViews = new Float32Array(4 * 16); this.flashlightOrigins = new Float32Array(4 * 3);
		this.blackCube = this.texture({faces:Array.from({length:6},()=>({width:1,height:1,data:new Uint8Array([0,0,0,255]),noMipmap:true})),flags:0});
		this.boneTexture = gl.createTexture(); this.textures.push(this.boneTexture);
		this.allocateBones(1024);
		if (this.hdr) {
			this.posePages = []; this.poseTarget = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER,this.poseTarget);
			gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,this.boneTexture,0); gl.bindFramebuffer(gl.FRAMEBUFFER,null);
			this.poseBuffer = gl.createBuffer(); this.buffers.push(this.poseBuffer);
			this.poseVao = this.vao([[this.buffer(new Float32Array([0,0,1,0,0,1,1,1])),[[0,2,0]],8],[this.poseBuffer,[[1,4,0],[2,3,16]],28]]);
			gl.bindVertexArray(this.poseVao); for (let i=1;i<=2;i++) gl.vertexAttribDivisor(i,1); gl.bindVertexArray(null);
		}
		this.overlayBuffer = gl.createBuffer(); this.buffers.push(this.overlayBuffer);
		this.overlayVao = this.vao([[this.overlayBuffer, [[0,3,0],[1,4,12]], 28]]);
		this.effectBuffer=gl.createBuffer();this.effectFrameBuffer=gl.createBuffer();this.buffers.push(this.effectBuffer,this.effectFrameBuffer);
		const effectBinding=[this.effectBuffer,[[0,3,0],[1,2,12],[2,4,20]],36];
		this.effectVao=this.vao([effectBinding]);this.effectFrameVao=this.vao([effectBinding,[this.effectFrameBuffer,[[3,3,0]],12]]);
		const corners=this.buffer(new Float32Array([-1,-1,1,-1,1,1,-1,-1,1,1,-1,1]));
		this.particleVertexVao=this.vao([[this.buffer(Float32Array.from({length:216},(_,i)=>i)),[[0,1,0]],4]]);
		this.coverageTexture=gl.createTexture();this.textures.push(this.coverageTexture);gl.bindTexture(gl.TEXTURE_2D,this.coverageTexture);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);
		this.empty = gl.createVertexArray(); this.vaos.push(this.empty);
		this.loadWorld(map);
		this.particles=new ReplayParticlesGPU(this,corners);
	}
	static modelLighting(map, origin, local) {
		const cube = SourceMap.ambient(map, origin); if (!cube) return null;
		const result = {cube, count:0}, lights = local ? SourceMap.worldLights(map, origin) : null; if (!lights) return result;
		for (let i = 0; i < 18; i++) cube[i] += lights.cube[i];
		result.count = lights.lights.length; result.pos = new Float32Array(16); result.color = new Float32Array(16); result.dir = new Float32Array(16); result.atten = new Float32Array(16);
		lights.lights.forEach((light, i) => { result.pos.set([...light.origin, light.type], i*4); result.color.set([...light.intensity, light.exponent], i*4); result.dir.set([...light.normal, light.stopdot], i*4); result.atten.set([...light.attenuation, light.stopdot2], i*4); });
		return result;
	}
	// VMT numbers: vectors such as $envmapcontrast ".5 .5 .5" (c8m5 puddles) take their first component;
	// Number() made them NaN, which turned the whole surface black.
	static num(value) { if (typeof value === 'number') return value; const m = String(value ?? '').match(/[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/i); return m ? Number(m[0]) : 0; }
	static normalize(v) { const n = Math.hypot(...v) || 1; return v.map(x => x / n); }
	// Source-space X forward, Y left, Z up. Survivor flashlight defaults are 53 degrees and 4..750 units.
	static flashlightProjection = (() => {
		const q = 1 / Math.tan(53 * Math.PI / 360), near = 4, far = 750;
		return new Float32Array([0,0,(far+near)/(far-near),1, -q,0,0,0, 0,q,0,0, 0,0,-2*near*far/(far-near),0]);
	})();
	// Worker side: merge static props into the world and cut every material batch into
	// XY grid chunks so the main and shadow passes can frustum-cull.
	static prepareWorld(map, models) {
		const propArrays = new WeakSet(), blocks = new Map(), skyMaterials = new Map(), reflectionMaterials = new Map(), push = (material, data) => { if(material?.visible===false)return;if (!blocks.has(material)) blocks.set(material, []); blocks.get(material).push(data); };
		for (const group of map.world) push(group.material, group.vertices);
		for (const prop of map.props) {
			const model = models[prop.model]; if (!model) continue; const m = ReplayRenderer.transform(prop.origin, prop.angles);
			const cube = SourceMap.ambient(map, prop.lightingOrigin);
			if (prop.scale) for (let i = 0; i < 12; i++) m[i] *= prop.scale;
			for (const group of model.groups) {
				if (group.base && Math.floor(prop.body / group.base) % group.variants !== group.variant) continue;
				const idx = group.indices, v = group.vertices, nr = group.normals, uv = group.uv, out = new Float32Array(idx.length * 12);
				for (let k = 0, o = 0; k < idx.length; k++, o += 12) {
					const i = idx[k], x = v[i*3], y = v[i*3+1], z = v[i*3+2], nx = nr[i*3], ny = nr[i*3+1], nz = nr[i*3+2];
					out[o] = m[0]*x + m[4]*y + m[8]*z + m[12]; out[o+1] = m[1]*x + m[5]*y + m[9]*z + m[13]; out[o+2] = m[2]*x + m[6]*y + m[10]*z + m[14];
					out[o+3] = m[0]*nx + m[4]*ny + m[8]*nz; out[o+4] = m[1]*nx + m[5]*ny + m[9]*nz; out[o+5] = m[2]*nx + m[6]*ny + m[10]*nz;
					out[o+6] = uv[i*2]; out[o+7] = uv[i*2+1]; out[o+8] = out[o+9] = out[o+10] = -1;
					const mesh = group.lightingIndices?.[i*2], vertex = group.lightingIndices?.[i*2+1], lighting = prop.vertexLighting?.[mesh];
					if (lighting && lighting.lod === group.lod) out.set(lighting.colors.subarray(vertex*3,vertex*3+3),o+8);
					else if (cube) {
						const normal = [out[o+3],out[o+4],out[o+5]], length = normal.reduce((sum,v)=>sum+v*v,0);
						for (let c = 0; c < 3; c++) out[o+8+c] = normal.reduce((sum,v,axis)=>sum+cube[(axis*2+(v<0?1:0))*3+c]*v*v,0)/length;
					}
				}
				let material = ReplayRenderer.modelMaterial(model, group, prop.skin);
				if (material?.values.$envmap === 'env_cubemap') {
					let texture = map.cubemapDefault, distance = Infinity;
					for (const sample of map.cubemaps) { const d = sample.origin.reduce((sum,v,k)=>sum+(v-prop.lightingOrigin[k])**2,0); if (d<distance) { distance=d;texture=sample.texture; } }
					if (!reflectionMaterials.has(material)) reflectionMaterials.set(material,new Map());
					const variants = reflectionMaterials.get(material); if (!variants.has(texture)) variants.set(texture,{...material,envmap:texture}); material=variants.get(texture);
				}
				if (prop.sky) { if (!skyMaterials.has(material)) skyMaterials.set(material, {...material, sky:true}); material = skyMaterials.get(material); }
				propArrays.add(out); push(material, out);
			}
			delete prop.vertexLighting;
		}
		for (const model of Object.values(models)) for (const group of model.groups) delete group.lightingIndices;
		// Cut each material into XY grid chunks (for frustum culling): count, then copy.
		const size = 1536 * 3, result = [];
		for (const [material, list] of blocks) {
			// BSP faces: orient by the plane normal. Static-prop triangles keep the model's winding
			// (SourceModel already converted it); re-deciding it here from one vertex normal culled
			// the outside of faces with smoothed normals and left props see-through.
			for (const v of list) if (!propArrays.has(v)) for (let i = 0; i < v.length; i += 36) {
				const ax = v[i+12]-v[i], ay = v[i+13]-v[i+1], az = v[i+14]-v[i+2], bx = v[i+24]-v[i], by = v[i+25]-v[i+1], bz = v[i+26]-v[i+2];
				if ((ay*bz-az*by)*v[i+3]+(az*bx-ax*bz)*v[i+4]+(ax*by-ay*bx)*v[i+5] < 0) for (let k = 0; k < 12; k++) { const x = v[i+12+k]; v[i+12+k] = v[i+24+k]; v[i+24+k] = x; }
			}
			const ids = new Map(), counts = [], bounds = [], assign = list.map(d => new Int32Array(d.length / 36));
			list.forEach((d, b) => {
				for (let t = 0, n = 0; t < d.length; t += 36, n++) {
					const key = (Math.floor((d[t] + d[t+12] + d[t+24]) / size) + 4096) * 8192 + Math.floor((d[t+1] + d[t+13] + d[t+25]) / size) + 4096;
					let id = ids.get(key); if (id === undefined) { ids.set(key, id = counts.length); counts.push(0); bounds.push([Infinity, Infinity, Infinity, -Infinity, -Infinity, -Infinity]); }
					assign[b][n] = id; counts[id]++; const bb = bounds[id];
					for (let o = t; o < t + 36; o += 12) for (let a = 0; a < 3; a++) { const val = d[o+a]; if (val < bb[a]) bb[a] = val; if (val > bb[a+3]) bb[a+3] = val; }
				}
			});
			const outs = counts.map(c => new Float32Array(c * 36)), fill = new Int32Array(counts.length);
			list.forEach((d, b) => { const a = assign[b]; for (let n = 0; n < a.length; n++) { const id = a[n]; outs[id].set(d.subarray(n * 36, n * 36 + 36), fill[id]); fill[id] += 36; } });
			outs.forEach((vertices, id) => result.push({material, vertices, bounds:bounds[id]}));
		}
		return result;
	}
	static transform(origin, angles) { const [p,y,r] = angles.map(v => v*Math.PI/180), cp = Math.cos(p), sp = Math.sin(p), cy = Math.cos(y), sy = Math.sin(y), cr = Math.cos(r), sr = Math.sin(r); return new Float32Array([cy*cp,sy*cp,-sp,0,cy*sp*sr-sy*cr,sy*sp*sr+cy*cr,cp*sr,0,cy*sp*cr+sy*sr,sy*sp*cr-cy*sr,cp*cr,0,...origin,1]); }
	static point(m, p, w = 1) { return [0,1,2].map(i => m[i]*p[0] + m[i+4]*p[1] + m[i+8]*p[2] + m[i+12]*w); }
	static modelMaterial(model, group, skin) { const index = model.skins[skin]?.[group.materialIndex] ?? group.materialIndex; return model.replacements[group.lod]?.[index] || model.materials[index]; }

	// ---- GL helpers -------------------------------------------------------------
	program(vertex, fragment, feedback) {
		const g = this.gl, p = g.createProgram();
		for (const [type, text] of [[g.VERTEX_SHADER, vertex], [g.FRAGMENT_SHADER, fragment]]) { const s = g.createShader(type); g.shaderSource(s, text); g.compileShader(s); if (!g.getShaderParameter(s, g.COMPILE_STATUS)) throw Error(g.getShaderInfoLog(s)); g.attachShader(p, s); g.deleteShader(s); }
		if(feedback)g.transformFeedbackVaryings(p,feedback,g.INTERLEAVED_ATTRIBS);
		g.linkProgram(p); if (!g.getProgramParameter(p, g.LINK_STATUS)) throw Error(g.getProgramInfoLog(p)); this.programs.push(p); this.uniformCache.set(p, new Map()); return p;
	}
	u(program, name) { const cache = this.uniformCache.get(program); if (!cache.has(name)) cache.set(name, this.gl.getUniformLocation(program, name)); return cache.get(name); }
	buffer(array, target = this.gl.ARRAY_BUFFER) { const g = this.gl, b = g.createBuffer(); g.bindBuffer(target, b); g.bufferData(target, array, g.STATIC_DRAW); this.buffers.push(b); return b; }
	vao(bindings, index = null) {
		const g = this.gl, v = g.createVertexArray(); g.bindVertexArray(v);
		for (const [buffer, attributes, stride] of bindings) { g.bindBuffer(g.ARRAY_BUFFER, buffer); for (const [at, size, offset] of attributes) { g.enableVertexAttribArray(at); g.vertexAttribPointer(at, size, g.FLOAT, false, stride, offset); } }
		if (index) g.bindBuffer(g.ELEMENT_ARRAY_BUFFER, index);
		g.bindVertexArray(null); this.vaos.push(v); return v;
	}
	texture(image, frame = 0, unit) {
		frame = Math.floor((frame%(image.frames || 1)+(image.frames || 1))%(image.frames || 1));
		if (image.gpu && (image.frame === frame || !image.source)) return image.gpu;
		if (image.source && (image.gpu || frame)) { const decoded=SourceTexture.decode(image.source,frame,false,!!image.compressed); image.data=decoded.data;image.levels=decoded.levels; }
		const g = this.gl, t = image.gpu || g.createTexture(), first = !image.gpu, target = image.faces ? g.TEXTURE_CUBE_MAP : g.TEXTURE_2D, images = image.faces || [image];
		// An upload must not overwrite the binding on the previous material's active unit.
		if (unit !== undefined) {
			g.activeTexture(g.TEXTURE0 + unit);
			if (this.unitBound[unit] !== t) { g.bindTexture(target, t); this.unitBound[unit] = t; }
		} else g.bindTexture(target, t);
		let mipmapped = true;
		for (let face = 0; face < images.length; face++) {
			const pixels = images[face], uploadTarget = image.faces ? g.TEXTURE_CUBE_MAP_POSITIVE_X+face : target;
			if (pixels.compressed && this.s3tc) {
				const format = {dxt1:this.s3tc.COMPRESSED_RGBA_S3TC_DXT1_EXT, dxt3:this.s3tc.COMPRESSED_RGBA_S3TC_DXT3_EXT, dxt5:this.s3tc.COMPRESSED_RGBA_S3TC_DXT5_EXT}[pixels.compressed];
				pixels.levels.forEach((level, i) => g.compressedTexImage2D(uploadTarget, i, format, level.width, level.height, 0, level.data));
				g.texParameteri(target, g.TEXTURE_MAX_LEVEL, pixels.levels.length - 1); mipmapped = pixels.levels.length > 1;
			} else if (pixels.compressed) throw Error('当前上下文未启用录像资源所需的 S3TC 纹理格式');
			else { g.texImage2D(uploadTarget, 0, pixels.float ? g.RGBA16F : g.RGBA, pixels.width, pixels.height, 0, g.RGBA, pixels.float ? g.FLOAT : g.UNSIGNED_BYTE, pixels.data); mipmapped = !pixels.noMipmap; }
			delete pixels.data; delete pixels.levels;
		}
		if (mipmapped && !images[0].compressed) g.generateMipmap(target);
		g.texParameteri(target, g.TEXTURE_WRAP_S, image.faces || image.flags & 4 ? g.CLAMP_TO_EDGE : g.REPEAT); g.texParameteri(target, g.TEXTURE_WRAP_T, image.faces || image.flags & 8 ? g.CLAMP_TO_EDGE : g.REPEAT);
		if (image.faces) g.texParameteri(target,g.TEXTURE_WRAP_R,g.CLAMP_TO_EDGE);
		g.texParameteri(target, g.TEXTURE_MAG_FILTER, g.LINEAR); g.texParameteri(target, g.TEXTURE_MIN_FILTER, mipmapped ? g.LINEAR_MIPMAP_LINEAR : g.LINEAR);
		const aniso = g.getExtension('EXT_texture_filter_anisotropic'); if (aniso && mipmapped) g.texParameterf(target, aniso.TEXTURE_MAX_ANISOTROPY_EXT, 4);
		if (first) this.textures.push(t); this.textureImages.add(image); image.gpu = t; image.frame=frame; return t;
	}
	// $alphatest wins over $translucent: L4D2 draws alpha-tested materials that are also marked
	// translucent ($allowfencerenderstatehack: chain-link fences and their concrete bases, foliage)
	// in the opaque pass with depth writes. Blending them without depth writes let a model's
	// hidden parts (the pipe socket inside the fence base) and the ground show through.
	transparent(material) { const v = material?.values; return material?.shader === 'water' || v?.$additive === '1' || v?.$translucent === '1' && v.$alphatest !== '1'; }
	allocateBones(rows) {
		const g = this.gl; this.boneCapacity = rows; g.bindTexture(g.TEXTURE_2D, this.boneTexture);
		g.texImage2D(g.TEXTURE_2D, 0, g.RGBA32F, 4, rows, 0, g.RGBA, g.FLOAT, null);
		for (const p of [g.TEXTURE_MIN_FILTER, g.TEXTURE_MAG_FILTER]) g.texParameteri(g.TEXTURE_2D, p, g.NEAREST);
	}

	// ---- Shaders ----------------------------------------------------------------
	compile() {
		const worldVertex = `#version 300 es
layout(location=0) in vec3 position;layout(location=1) in vec3 normals;layout(location=2) in vec2 texcoord;layout(location=3) in vec3 lighting;layout(location=4) in float alpha;
uniform mat4 view;out vec3 vNormal;out vec2 vUv;out vec3 vBaked;out float vBlend;out vec3 vWorld;
void main(){vWorld=position;vNormal=normals;vUv=texcoord;vBaked=lighting;vBlend=alpha;gl_Position=view*vec4(position,1.0);}`;
		const skinVertex = `#version 300 es
layout(location=0) in vec3 position;layout(location=1) in vec3 normals;layout(location=2) in vec2 texcoord;layout(location=3) in vec3 weight;layout(location=4) in vec3 bone;layout(location=5) in vec3 lighting;
uniform highp sampler2D boneTex;uniform int boneOffsets[64];uniform mat4 view;out vec3 vNormal;out vec2 vUv;out vec3 vBaked;out float vBlend;out vec3 vWorld;
mat4 bm(int i){i+=boneOffsets[gl_InstanceID];return mat4(texelFetch(boneTex,ivec2(0,i),0),texelFetch(boneTex,ivec2(1,i),0),texelFetch(boneTex,ivec2(2,i),0),texelFetch(boneTex,ivec2(3,i),0));}
void main(){mat4 m=bm(int(bone.x))*weight.x+bm(int(bone.y))*weight.y+bm(int(bone.z))*weight.z;vWorld=(m*vec4(position,1.0)).xyz;vNormal=mat3(m)*normals;vUv=texcoord;vBaked=lighting;vBlend=0.0;gl_Position=view*vec4(vWorld,1.0);}`;
		const fragment = `#version 300 es
precision highp float;precision highp sampler2DShadow;
in vec3 vNormal;in vec2 vUv;in vec3 vBaked;in float vBlend;in vec3 vWorld;
uniform sampler2D baseTex;uniform sampler2D secondTex;uniform sampler2D maskTex;uniform sampler2D emissionTex;uniform sampler2D characterTex;uniform sampler2DShadow shadowTex;
uniform int flashlightCount;uniform mat4 flashlightView[4];uniform vec3 flashlightOrigin[4];uniform sampler2D flashlightCookie;uniform sampler2DShadow flashlightDepth;
uniform mat4 lightView;uniform vec3 tint;uniform vec3 glowTint;uniform vec3 eye;uniform vec3 sunDir;uniform vec4 options;uniform vec4 surface;uniform float cut;
uniform vec2 tintBlend;
uniform highp samplerCube envmapTex;uniform sampler2D envmapMaskTex;uniform vec4 envOptions;uniform vec4 envControls;uniform vec3 envTint;uniform vec3 envFresnel;uniform vec3 envBaseMask;
uniform float toonStyle;uniform vec2 shadowSoft;uniform float eyeOn;uniform vec3 eyeOrg;uniform vec3 eyeRight;uniform vec3 eyeUp;uniform vec3 eyeFwd;uniform sampler2D normalTex;uniform sampler2D expTex;uniform sampler2D lightwarpTex;uniform vec4 diffuseOptions;uniform vec4 phong;uniform vec4 phongExtra;uniform vec4 phongTint;uniform float realism;
uniform float character;uniform float ownedItem;uniform vec4 rim;uniform float shadowOn;uniform float shadowTexel;
uniform float time;uniform float entityAlpha;uniform float skySurface;uniform vec3 sunColor;uniform vec3 skyColor;uniform float daylight;
uniform vec3 ambientCube[6];uniform float ambientOn;uniform sampler2DShadow staticShadowTex;uniform float mapLight;
uniform int localCount;uniform vec4 localPos[4];uniform vec4 localColor[4];uniform vec4 localDir[4];uniform vec4 localAtten[4];
uniform vec3 skyFogColor;uniform vec3 skyFogRange;uniform vec3 viewForward;
uniform sampler2D flowTex;uniform vec4 water;uniform vec3 waterTint;uniform sampler2D lightmapTex;uniform float lightmapOn;
layout(location=0) out vec4 color;layout(location=1) out vec4 glow;layout(location=2) out vec4 gbuf;
float band(float x,float e,float s){return smoothstep(e-s,e+s,x);}
vec3 ambientLight(vec3 n){vec3 weight=n*n;return weight.x*ambientCube[n.x<0.0?1:0]+weight.y*ambientCube[n.y<0.0?3:2]+weight.z*ambientCube[n.z<0.0?5:4];}
// Toon: hard steps every 2/3 octave of light (chroma kept), flatter and more saturated albedo.
vec3 toonBand(vec3 light){float lum=dot(light,vec3(.2126,.7152,.0722)),level=log2(max(lum,1e-7))*1.5,q=floor(level),f=fract(level);float tone=exp2((q+smoothstep(.44,.56,f))/1.5);return tone*mix(vec3(1.0),clamp(light/max(lum,1e-7),vec3(0.0),vec3(2.0)),.75);}
vec3 toonAlbedo(vec3 a,vec3 coarse,float flatten){float l=dot(a,vec3(.2126,.7152,.0722)),lc=dot(coarse,vec3(.2126,.7152,.0722));a*=mix(1.0,clamp(lc/max(l,1e-5),.25,4.0),flatten);l=dot(a,vec3(.2126,.7152,.0722));
 return max(mix(vec3(l),a,1.4),vec3(0.0));}
vec3 celLight(vec3 light){float lum=dot(light,vec3(.2126,.7152,.0722)),level=log2(max(lum,1e-7));float tone=exp2(floor(level)+smoothstep(.35,.65,fract(level)));return tone*mix(vec3(1.0),clamp(light/max(lum,1e-7),vec3(0.0),vec3(2.0)),.65);}
vec3 fogSky(vec3 light){if(skySurface<.5)return light;float distance=dot(vWorld-eye,viewForward),fog=clamp(min(skyFogRange.z,(distance-skyFogRange.x)/max(1.0,skyFogRange.y-skyFogRange.x)),0.0,1.0);return mix(light,skyFogColor,min(fog*fog,toonStyle>.5?.6:1.0));}
vec3 mappedNormal(vec3 n,vec4 texel){vec3 t=texel.xyz*2.0-1.0;vec3 dp1=dFdx(vWorld),dp2=dFdy(vWorld);vec2 du1=dFdx(vUv),du2=dFdy(vUv);vec3 c2=cross(dp2,n),c1=cross(n,dp1),T=c2*du1.x+c1*du2.x,B=c2*du1.y+c1*du2.y;float im=inversesqrt(max(max(dot(T,T),dot(B,B)),1e-20));return normalize(mat3(T*im,B*im,n)*t);}
vec3 lightTexel(ivec2 p){vec4 value=texelFetch(lightmapTex,p,0);float exponent=floor(value.a*255.0+.5);if(exponent>127.0)exponent-=256.0;return value.rgb*exp2(exponent);}
vec3 bakedLight(){ivec2 p=ivec2(floor(vBaked.xy));vec2 f=fract(vBaked.xy);return mix(mix(lightTexel(p),lightTexel(p+ivec2(1,0)),f.x),mix(lightTexel(p+ivec2(0,1)),lightTexel(p+ivec2(1,1)),f.x),f.y);}
// Soft shadows (PCSS): blocker search on raw depth (the shadow map is also bound, without compare,
// on the flow-map unit, which only water uses), penumbra from the blocker-receiver distance and the
// sun's angular size, then a rotated 16-tap Poisson PCF of that width.
const vec2 poisson[16]=vec2[16](vec2(-.94,-.40),vec2(.95,-.77),vec2(-.09,-.93),vec2(.34,.29),vec2(-.92,.46),vec2(-.82,-.15),vec2(-.38,.28),vec2(-.70,-.70),vec2(.56,-.38),vec2(-.18,-.66),vec2(.23,-.92),vec2(.61,.53),vec2(.90,.18),vec2(.31,.83),vec2(-.33,.92),vec2(.03,.40));
float softVisibility(vec3 p,float bias){float a=fract(sin(dot(gl_FragCoord.xy,vec2(12.9898,78.233)))*43758.5453)*6.2831,c=cos(a),s=sin(a);mat2 rot=mat2(c,s,-s,c);
 float blockers=0.0,count=0.0;for(int i=0;i<12;i++){float d=texture(flowTex,p.xy+rot*poisson[i]*shadowTexel*shadowSoft.x).r;if(d<p.z-bias){blockers+=d;count+=1.0;}}
 if(count<.5)return 1.0;float penumbra=clamp((p.z-blockers/count)*shadowSoft.y,1.0,shadowSoft.x);
 float sum=0.0;for(int i=0;i<16;i++)sum+=texture(shadowTex,vec3(p.xy+rot*poisson[i]*shadowTexel*penumbra,p.z-bias));return sum/16.0;}
float visibility(vec3 n){if(shadowOn<.5)return 1.0;vec4 c=lightView*vec4(vWorld,1.0);vec3 p=c.xyz/c.w*.5+.5;if(any(lessThan(p.xy,vec2(0)))||any(greaterThan(p.xy,vec2(1)))||p.z>1.0)return 1.0;
 float bias=.00004+.00020*(1.0-clamp(dot(n,sunDir),0.0,1.0));vec2 o=vec2(shadowTexel*.75);
 if(shadowSoft.x>0.0&&water.x<.5)return softVisibility(p,bias);
 return .25*(texture(shadowTex,vec3(p.xy+o*vec2(-.7,-.3),p.z-bias))+texture(shadowTex,vec3(p.xy+o*vec2(.3,-.7),p.z-bias))+texture(shadowTex,vec3(p.xy+o*vec2(.7,.3),p.z-bias))+texture(shadowTex,vec3(p.xy+o*vec2(-.3,.7),p.z-bias)));}
// Shadow-map test with an explicit map: the world-only (static) map tells which part of the
// sun shadow is already baked into lightmaps; the difference to the full map is actors' shadow.
float staticVisibility(vec3 n){vec4 c=lightView*vec4(vWorld,1.0);vec3 p=c.xyz/c.w*.5+.5;if(any(lessThan(p.xy,vec2(0)))||any(greaterThan(p.xy,vec2(1)))||p.z>1.0)return 1.0;
 float bias=.00004+.00020*(1.0-clamp(dot(n,sunDir),0.0,1.0));vec2 o=vec2(shadowTexel*.75);
 return .25*(texture(staticShadowTex,vec3(p.xy+o*vec2(-.7,-.3),p.z-bias))+texture(staticShadowTex,vec3(p.xy+o*vec2(.3,-.7),p.z-bias))+texture(staticShadowTex,vec3(p.xy+o*vec2(.7,.3),p.z-bias))+texture(staticShadowTex,vec3(p.xy+o*vec2(-.3,.7),p.z-bias)));}
// Engine local lights (dworldlight_t point/spot): 1/(c+l*d+q*d*d) falloff, spot cone with
// exponent and stopdot..stopdot2 fade, Lambert (or half-Lambert) per pixel.
vec3 localLight(vec3 n,bool halfLambert){vec3 sum=vec3(0.0);for(int i=0;i<4;i++){if(i>=localCount)break;vec3 L=localPos[i].xyz-vWorld;float d2=max(dot(L,L),1.0),d=sqrt(d2);vec3 dir=L/d;
 float ratio=1.0/max(1e-6,localAtten[i].x+localAtten[i].y*d+localAtten[i].z*d2);
 if(localPos[i].w>1.5){float dt=dot(-dir,localDir[i].xyz);if(dt<=localAtten[i].w)continue;if(localColor[i].w>0.0)ratio*=pow(dt,localColor[i].w);if(dt<=localDir[i].w)ratio*=(dt-localAtten[i].w)/max(1e-6,localDir[i].w-localAtten[i].w);}
 float nl=dot(n,dir);nl=halfLambert?(nl*.5+.5)*(nl*.5+.5):max(nl,0.0);sum+=localColor[i].rgb*ratio*nl;}return sum;}
vec3 localSpecular(vec3 N,vec3 v,float e){vec3 sum=vec3(0.0);for(int i=0;i<4;i++){if(i>=localCount)break;vec3 L=localPos[i].xyz-vWorld;float d2=max(dot(L,L),1.0),d=sqrt(d2);vec3 dir=L/d;
 float ratio=1.0/max(1e-6,localAtten[i].x+localAtten[i].y*d+localAtten[i].z*d2);
 if(localPos[i].w>1.5){float dt=dot(-dir,localDir[i].xyz);if(dt<=localAtten[i].w)continue;if(dt<=localDir[i].w)ratio*=(dt-localAtten[i].w)/max(1e-6,localDir[i].w-localAtten[i].w);}
 sum+=localColor[i].rgb*ratio*pow(max(dot(reflect(-v,N),dir),0.0),e)*max(dot(N,dir),0.0);}return sum;}
vec3 flashlightLight(vec3 n){
 vec3 sum=vec3(0.0);
 vec2 texel=2.0/vec2(textureSize(flashlightDepth,0)); // UVs are local to one atlas tile.
 for(int i=0;i<flashlightCount;i++){
  vec4 clip=flashlightView[i]*vec4(vWorld,1.0);
  vec3 p=clip.xyz/max(clip.w,.001)*.5+.5,dx=dFdx(p),dy=dFdy(p);
  if(clip.w<=0.0||any(greaterThanEqual(abs(clip.xyz),vec3(clip.w))))continue;
  vec3 cookie=texture(flashlightCookie,vec2(p.x,1.0-p.y)).rgb,L=flashlightOrigin[i]-vWorld;
  float dist=length(L),nl=max(dot(n,L/dist),0.0);
  if(nl<=0.0||all(equal(cookie,vec3(0.0))))continue;
  // Filter the shadow over three texels. At grazing angles each tap lies at a different wall depth.
  float det=dx.x*dy.y-dx.y*dy.x;
  vec2 slope=abs(det)>1e-12?vec2(dx.z*dy.y-dx.y*dy.z,dx.x*dy.z-dx.z*dy.x)/det:vec2(0.0);
  vec2 tile=vec2(i&1,i>>1);
  float depth=p.z-(.008+.03*(1.0-nl))/clip.w,visible=0.0;
  for(int j=0;j<16;j++){
   vec2 uv=clamp(p.xy+poisson[j]*3.0*texel,.5*texel,1.0-.5*texel);
   visible+=texture(flashlightDepth,vec3((tile+uv)*.5,depth+dot(slope,uv-p.xy)));
  }
  float attenuation=min(1.0,100.0/dist)*(1.0-smoothstep(450.0,750.0,dist));
  sum+=cookie*(nl*attenuation*visible/16.0);
 }
 return sum;
}
void main(){if(skySurface<.5&&vWorld.z>cut)discard;vec4 tex=mix(texture(baseTex,vUv),texture(secondTex,vUv),vBlend*surface.w);
 if(water.x>.5){
  bool above=eye.z>=vWorld.z;if(above!=(water.y>.5))discard;
  vec2 flow=texture(flowTex,vWorld.xy*.0006).rg*2.0-1.0;float phase=fract(time*.22),phase2=fract(phase+.5);
  vec2 uv=vWorld.xy/180.0,scroll=flow*.35+vec2(.03,.02);
  vec3 a=texture(normalTex,uv-scroll*phase).xyz*2.0-1.0,b=texture(normalTex,uv-scroll*phase2+vec2(.3)).xyz*2.0-1.0;
  vec3 n=normalize(mix(a,b,abs(phase*2.0-1.0))*vec3(.4,.4,1.0));if(!above)n=-n;
  vec3 v=normalize(eye-vWorld);float fres=.04+.96*pow(1.0-max(dot(n,v),0.0),5.0),spec=pow(max(dot(n,normalize(v+sunDir)),0.0),90.0)*visibility(n);
  vec3 reflected=mix(skyColor*.5,skyColor,clamp(reflect(-v,n).z*.5+.5,0.0,1.0));
  vec3 lit=mix(waterTint*(.22+.45*daylight),reflected,fres)+sunColor*spec*.8;
  if(skySurface<.5)lit+=waterTint*flashlightLight(n);
  color=vec4(fogSky(lit),clamp(.36+fres*.56,0.0,1.0)*entityAlpha);glow=vec4(0.0);gbuf=vec4(n*.5+.5,1.0);return;
 }
 // Infected RGB packs masks; alpha addresses the palette (default skin/clothing rows 0/8).
 if(surface.z>.5){float mask=tex.b*2.0-1.0;vec3 palette=textureLod(characterTex,vec2(clamp(tex.a,.5/256.0,255.5/256.0),mask>=0.0?.5/16.0:8.5/16.0),0.0).rgb;tex=vec4(mix(vec3(tex.a),palette,abs(mask)),1.0);}
 if(tex.a<surface.x)discard;
 // Orient the vertex normal with the camera-facing geometric normal (works for either winding).
 vec3 v=normalize(eye-vWorld),fn=normalize(cross(dFdx(vWorld),dFdy(vWorld)));if(dot(fn,v)<0.0)fn=-fn;vec3 n=normalize(vNormal);if(dot(n,fn)<0.0)n=-n;
 vec3 base=pow(max(tex.rgb,vec3(0.0)),vec3(2.2)),modulation=pow(max(tint,vec3(0.0)),vec3(2.2));
 vec3 albedo=tintBlend.x>.5?mix(base,mix(base*modulation,modulation,tintBlend.y),tex.a):base*modulation;
 // Toon uses exactly the realistic light (lightmaps, vertex light, cube + lamps) and stylises every
 // surface the same way: gently flattened, slightly richer albedo, a soft rim; banding is in post.
 bool toon=toonStyle>.5&&water.x<.5&&options.w<.5;
 if(toon&&surface.z<.5){vec3 coarse=pow(max(textureLod(baseTex,vUv,3.5).rgb,vec3(0.0)),vec3(2.2))*(tintBlend.x>.5?vec3(1.0):modulation);albedo=toonAlbedo(albedo,tintBlend.x>.5?albedo:coarse,.35);}
 float ndl=dot(n,sunDir),vis=visibility(n);
 vec3 sky=skyColor,ground=vec3(.36,.30,.28)*mix(.02,1.0,daylight),shade=vec3(.40,.44,.66)*mix(.03,1.0,daylight),sun=sunColor;
 // Custom time of day keeps the map's light (cube, lamps) like the world does and adds the chosen sky.
 vec3 hemi=ambientOn>.5?(mapLight>.5?ambientLight(n):ambientLight(n)*mix(1.0,.35,daylight)+mix(ground,sky,n.z*.5+.5)*.35):mix(ground,sky,n.z*.5+.5);vec3 lit;float mask=.5;vec3 extra=vec3(0.0),envNormal=n;
 if(character>.5&&realism>.5){
  // Source diffuse warp and reflection-vector Phong use the material's masks and ranges.
  float kind=phong.w;vec4 nm=phongExtra.w>.5?texture(normalTex,vUv):vec4(.5,.5,1.0,1.0);vec3 N=n;
  if(phongExtra.w>.5&&phongTint.w<1.5)N=mappedNormal(n,nm);envNormal=N;
  // Eyeballs (EyeRefract): sclera plus the iris texture projected from the MDL eyeball the way
  // R_StudioEyeballPosition builds it (u,v = -dot(p-org, right|up)*iris_scale + .5). The $iris texture
  // carries the iris and the sclera around it (its alpha is not an iris mask); clamped UVs continue the
  // sclera, darker towards the rim. No cornea/refraction; the cornea $envmap is not applied.
  if(kind>2.5&&kind<3.5){vec3 sclera=vec3(.50,.47,.44);albedo=sclera;
   if(eyeOn>.5){vec3 d=vWorld-eyeOrg;vec2 iuv=vec2(dot(d,eyeRight),dot(d,eyeUp))+.5;float front=dot(normalize(d),eyeFwd);
    vec4 it=texture(characterTex,clamp(iuv,0.0,1.0));
    albedo=pow(max(it.rgb,vec3(0.0)),vec3(2.2))*.9;albedo=mix(sclera,albedo,step(0.0,front));albedo*=mix(.45,1.0,smoothstep(-.35,.45,front));}}
  float specMask=phongTint.w>1.5?tex.a:phongTint.w>.5?nm.a:1.0,NdL=dot(N,sunDir),term=clamp(diffuseOptions.x>.5?NdL*.5+.5:NdL,0.0,1.0);
  vec3 diff=diffuseOptions.y>.5?texture(lightwarpTex,vec2(term,.5)).rgb*2.0:vec3(diffuseOptions.x>.5?term*term:term);
  vec4 exponent=phong.z>.5?texture(expTex,vUv):vec4(1.0);float e=diffuseOptions.z>0.0?1.0+diffuseOptions.z*exponent.r:phong.y>0.0?phong.y:1.0+149.0*exponent.r,f=pow(clamp(1.0-dot(N,v),0.0,1.0),2.0);
  float F=f<.5?mix(phongExtra.x,phongExtra.y,f*2.0):mix(phongExtra.y,phongExtra.z,f*2.0-1.0),lobe=pow(max(dot(reflect(-v,N),sunDir),0.0),e);
  vec3 specTint=diffuseOptions.w>.5?mix(vec3(1.0),base,exponent.g):phongTint.rgb,spec=sun*lobe*F*specMask*phong.x*max(NdL,0.0)*vis*specTint;
  spec+=localSpecular(N,v,e)*F*specMask*phong.x*specTint;
  lit=albedo*(sun*diff*vis+(ambientOn>.5?(mapLight>.5?ambientLight(N):ambientLight(N)*mix(1.0,.35,daylight)+mix(ground,sky,N.z*.5+.5)*.35):mix(ground,sky,N.z*.5+.5)*.40)+localLight(N,diffuseOptions.x>.5))+spec;mask=.62;
 }else if(character>.5){
  // Two-tone cel ramp with a soft terminator, crisp specular and a coloured rim.
  float light=band(ndl*.5+.5,.50,.01)*mix(.25,1.0,step(.5,vis));
  vec3 diffuse=ambientOn>.5?toonBand(hemi+sun*light+localLight(n,false)):toonBand(mix(shade,sun,light)+hemi*.22+localLight(n,false));
  float spec=band(pow(max(dot(n,normalize(sunDir+v)),0.0),48.0),.45,.08)*vis*.35;
  float fres=1.0-max(dot(n,v),0.0),rimBand=band(fres,.70,.035)*(.35+.65*light);
  lit=albedo*diffuse+sun*spec+rim.rgb*rimBand*rim.a*.75;extra=rim.rgb*rimBand*rim.a*.35;mask=1.0;
 }else{
  // World: the map's baked lighting, banded into three soft tones, keeps indoor/outdoor
  // contrast; the sun adds a crisp warm key where its shadow map sees the surface.
  bool dynamicModel=lightmapOn<.5&&vBaked.x<0.0;
  vec3 baked=lightmapOn>.5?bakedLight():dynamicModel?hemi*(ambientOn>.5?1.0:.45)+sun*max(ndl,0.0)*vis+localLight(n,false):max(vBaked,vec3(0.0));
  if(realism>.5){
   // Realistic: the map's light as the engine applies it. Lightmaps and static-prop vertex light
   // already contain the sun and its world shadows; only actors' shadows (full minus world-only
   // shadow map) are taken out, like Source's projected shadows. With a custom time of day the
   // map's light is kept for lamps and the chosen sun/sky is added on top.
   if(!dynamicModel){float occ=shadowOn>.5?clamp(staticVisibility(n)-vis,0.0,1.0):0.0;baked*=1.0-.6*occ;
    if(mapLight<.5)baked=baked*mix(1.0,.35,daylight)+sun*max(ndl,0.0)*vis+hemi*.35;}
   lit=albedo*baked;
  }else{
  float lum=dot(baked,vec3(.2126,.7152,.0722));
  float key=step(.08,ndl)*step(.5,vis)*smoothstep(.02,.2,lum);
  lit=albedo*(toonBand(baked)+sun*key*.3+hemi*.03);}
 }
 if(skySurface<.5&&options.w<.5)lit+=albedo*flashlightLight(envNormal);
 if(toon){
  // Lift the value along the shaded RGB colour. Where lighting is zero, the texture supplies the hue.
  const vec3 luma=vec3(.2126,.7152,.0722);
  float light=dot(lit,luma)/max(dot(albedo,luma),1e-5),shade=1.0-smoothstep(.01,.16,light);
  vec3 shadeColor=mix(albedo,lit/max(light,1e-5),smoothstep(0.0,.002,light));
  lit+=shadeColor*(.016*shade);
  float fr=1.0-max(dot(n,v),0.0);lit*=1.0+smoothstep(.55,.75,fr)*.25;
 }
 vec3 m=options.y>0.5?texture(maskTex,vUv).rgb:vec3(tex.a);
 lit=mix(lit,albedo,options.w);
 vec3 selfIllum=albedo*glowTint,emission=pow(texture(emissionTex,vUv).rgb,vec3(2.2))*options.z;
 lit=mix(lit,selfIllum,m*options.x)+emission;
 if(envOptions.x>.5){
  vec4 nm=phongExtra.w>.5?texture(normalTex,vUv):vec4(.5,.5,1.0,1.0);if(phongExtra.w>.5&&!(character>.5&&realism>.5))envNormal=mappedNormal(n,nm);
  vec3 specMask=vec3(1.0);if(envOptions.z>.5&&envOptions.z<1.5)specMask=texture(envmapMaskTex,vUv).rgb;else if(envOptions.z<2.5&&envOptions.z>1.5)specMask=vec3(mix(envBaseMask.x,envBaseMask.y,pow(tex.a,envBaseMask.z)));else if(envOptions.z>2.5)specMask=vec3(envOptions.z<3.5?nm.a:tex.a);
  if(envOptions.w>.5)specMask=mix(specMask,vec3(1.0)-specMask,envControls.w);
  float f=clamp(1.0-dot(envNormal,v),0.0,1.0),fresnel;
  if(envOptions.w>.5){f*=f;fresnel=f<.5?mix(envFresnel.x,envFresnel.y,f*2.0):mix(envFresnel.y,envFresnel.z,f*2.0-1.0);}else fresnel=mix(envFresnel.x,envFresnel.y,pow(f,envFresnel.z));
  vec3 reflected=texture(envmapTex,reflect(-v,envNormal)).rgb;if(envOptions.y<.5)reflected=pow(max(reflected,vec3(0.0)),vec3(2.2));
  reflected*=specMask*envTint*mix(1.0,fresnel,envControls.x);reflected=mix(reflected,reflected*reflected,envControls.y);reflected=mix(vec3(dot(reflected,vec3(.299,.587,.114))),reflected,envControls.z);lit+=reflected;
 }
 color=vec4(fogSky(lit),(surface.y>0.5?tex.a:1.0)*entityAlpha);glow=vec4(selfIllum*m*options.x+emission+extra,1.0);gbuf=vec4(n*.5+.5,max(mask,ownedItem*.62));}`;
		const shadowFragment = `#version 300 es
precision highp float;in vec2 vUv;in float vBlend;in vec3 vWorld;uniform sampler2D baseTex;uniform sampler2D secondTex;uniform vec4 surface;uniform float cut;
void main(){if(vWorld.z>cut||(surface.z<.5&&mix(texture(baseTex,vUv),texture(secondTex,vUv),vBlend*surface.w).a<surface.x))discard;}`;
		const xrayFragment = `#version 300 es
precision highp float;in vec3 vNormal;in vec3 vWorld;uniform vec3 eye;uniform vec4 rim;uniform sampler2D actorMask;
layout(location=0) out vec4 color;layout(location=1) out vec4 glow;
void main(){if(texelFetch(actorMask,ivec2(gl_FragCoord.xy),0).a>.55)discard;vec3 n=normalize(vNormal);float fres=1.0-abs(dot(n,normalize(eye-vWorld)));
 float stripe=step(.5,fract((gl_FragCoord.x-gl_FragCoord.y)/7.0));float a=clamp(.16+.62*pow(fres,1.6)+stripe*.10,0.0,.85);
 color=vec4(rim.rgb*(1.15+.35*stripe),a);glow=vec4(rim.rgb*a*.5,a);}`;
		this.worldProgram = this.program(worldVertex, fragment); this.skinProgram = this.program(skinVertex, fragment);
		this.viewModelProgram = this.program(`#version 300 es
layout(location=0) in vec3 position;layout(location=1) in vec3 normals;layout(location=2) in vec2 texcoord;layout(location=3) in vec3 weight;layout(location=4) in vec3 bone;
uniform highp sampler2D clipTex;uniform int firstBone;uniform float phase;uniform mat4 root,view;
out vec3 vWorld,vNormal,vBaked;out vec2 vUv;out float vBlend;
vec4 columnAt(int x){int a=int(floor(phase)),b=min(a+1,textureSize(clipTex,0).y-1);return mix(texelFetch(clipTex,ivec2(x,a),0),texelFetch(clipTex,ivec2(x,b),0),fract(phase));}
mat4 boneAt(float id){int x=(firstBone+int(id))*4;return mat4(columnAt(x),columnAt(x+1),columnAt(x+2),columnAt(x+3));}
void main(){mat4 m=root*(boneAt(bone.x)*weight.x+boneAt(bone.y)*weight.y+boneAt(bone.z)*weight.z);vWorld=(m*vec4(position,1)).xyz;vNormal=mat3(m)*normals;vBaked=vec3(-1);vUv=texcoord;vBlend=0.;gl_Position=view*vec4(vWorld,1);}`,fragment);
		this.shadowWorld = this.program(worldVertex, shadowFragment); this.shadowSkin = this.program(skinVertex, shadowFragment);
		// The third-person beam in survivor_fx.pcf distributes 18 additive glow sprites along the light.
		this.flashlightBeam = this.program(`#version 300 es
uniform mat4 view,projector;uniform vec3 origin,eye;out vec2 uv;out vec4 projected;out float height,strength;
const vec2 corner[6]=vec2[6](vec2(-1,-1),vec2(1,-1),vec2(1,1),vec2(-1,-1),vec2(1,1),vec2(-1,1));
void main(){
 vec3 forward=vec3(projector[0].w,projector[1].w,projector[2].w);
 vec3 right=normalize(vec3(view[0].x,view[1].x,view[2].x)),up=normalize(vec3(view[0].y,view[1].y,view[2].y));
 float t=float(gl_InstanceID)/17.0;vec2 xy=corner[gl_VertexID];uv=xy*.5+.5;
 vec3 world=origin+forward*mix(5.0,320.0,t)+(right*xy.x+up*xy.y)*mix(5.0,160.0,t);
 float facing=max(dot(forward,normalize(eye-origin)),0.0);
 strength=gl_InstanceID==0?.6*facing*facing:.05*(1.0-smoothstep(.75,1.0,t));
 height=world.z;projected=projector*vec4(world,1.0);gl_Position=view*vec4(world,1.0);
}`,`#version 300 es
precision highp float;precision highp sampler2DShadow;
in vec2 uv;in vec4 projected;in float height,strength;uniform sampler2D sprite;uniform sampler2DShadow depthAtlas;uniform vec2 tile;uniform float cut,overbright;out vec4 color;
void main(){
 if(height>cut||projected.w<=0.0||any(greaterThanEqual(abs(projected.xyz),vec3(projected.w))))discard;
 vec3 p=projected.xyz/projected.w*.5+.5;float edge=1.0-smoothstep(.7,1.0,length(p.xy*2.0-1.0));
 float visible=texture(depthAtlas,vec3((tile+clamp(p.xy,.001,.999))*.5,p.z));
 vec4 tex=texture(sprite,uv);color=vec4(tex.rgb*(tex.a*overbright*strength*edge*visible),0.0);
}`);
		this.xrayProgram = this.program(skinVertex, xrayFragment);
		const hullVertex = skinVertex.replace('uniform mat4 view;', 'uniform mat4 view;uniform float inflate;').replace('vWorld=(m*vec4(position,1.0)).xyz;vNormal=mat3(m)*normals;', 'vNormal=mat3(m)*normals;vWorld=(m*vec4(position,1.0)).xyz+normalize(vNormal)*inflate;');
		if (!hullVertex.includes('inflate;') || !hullVertex.includes('*inflate')) throw new Error('hull vertex shader patch failed');
		this.hullProgram = this.program(hullVertex, `#version 300 es
precision highp float;uniform vec4 rim;layout(location=0) out vec4 color;void main(){color=vec4(rim.rgb*.85,1.0);}`);
		const overlayFragment=`#version 300 es
precision highp float;in vec4 vColour;in float vZ;uniform float cut;uniform float glowAmount;layout(location=0) out vec4 color;layout(location=1) out vec4 glow;
void main(){if(vZ>cut)discard;color=vColour;glow=vec4(vColour.rgb*glowAmount*vColour.a,1.0);}`;
		this.overlayProgram = this.program(`#version 300 es
layout(location=0) in vec3 position;layout(location=1) in vec4 colour;uniform mat4 view;out vec4 vColour;out float vZ;
void main(){vColour=colour;vZ=position.z;gl_Position=view*vec4(position,1.0);}`,overlayFragment);
		this.throwableProgram=this.program(ReplayThrowables.vertex,overlayFragment);
		this.effectProgram=this.program(`#version 300 es
layout(location=0)in vec4 position;layout(location=1)in vec2 texcoord;layout(location=2)in vec4 tint;layout(location=3)in vec4 nextFrame;layout(location=4)in vec4 uvRect;
layout(location=5)in vec4 nextRect;layout(location=6)in vec3 velocity;
uniform mat4 view;uniform bool particle;uniform vec2 crop,trailLengths;uniform vec4 sizes,space;uniform vec3 eye;uniform float velocityAngle,visibility;out vec2 uv;out vec3 frame;out vec4 tone;out float height;
void main(){vec3 world=position.xyz;uv=texcoord;frame=nextFrame.xyz;tone=tint;
 if(particle){
  vec3 right=normalize(vec3(view[0].x,view[1].x,view[2].x)),up=normalize(vec3(view[0].y,view[1].y,view[2].y));
  float radius=position.w,angle=nextFrame.x;
  tone.a*=visibility;
   if(velocityAngle<10.0 && dot(velocity,velocity)>0.0)angle=atan(dot(velocity,up),dot(velocity,right))+velocityAngle;
   if(sizes.w>=0.0){float dist=distance(world,eye);radius=max(radius,sizes.x*dist);float fade=radius<=sizes.z*dist?1.0:clamp((sizes.w*dist-radius)/max(.00001,(sizes.w-sizes.z)*dist),0.,1.);tone.a*=fade;tone.rgb*=pow(fade,1./2.2);radius=min(radius,sizes.y*dist);}
   if(tone.a<=0.0||radius<=0.0){gl_Position=vec4(2,2,2,1);height=0.0;return;}
  vec3 yawRight=right*cos(nextFrame.y)+cross(up,right)*sin(nextFrame.y);float c=cos(angle),s=sin(angle);
  vec2 corner=texcoord*crop;
  if(trailLengths.y>=0.){float speed=length(velocity),len=clamp(speed*nextFrame.w,trailLengths.x,trailLengths.y);if(speed<=0.||len<=0.){gl_Position=vec4(2,2,2,1);height=0.;return;}vec3 dir=-velocity/speed,axis=cross(world-eye,dir);world+=dir*len*(texcoord.y*.5+.5)-axis/max(length(axis),.00001)*texcoord.x*min(radius,len)*.5;}
  else world+=radius*((yawRight*c+up*s)*corner.x+(up*c-yawRight*s)*corner.y);
  world=(world-space.xyz)*space.w;
  uv=mix(uvRect.xy,uvRect.zw,.5+.5*corner*vec2(1,-1));
  frame=vec3(mix(nextRect.xy,nextRect.zw,.5+.5*corner*vec2(1,-1)),nextFrame.z);
 }
 height=world.z;gl_Position=view*vec4(world,1.0);}`,`#version 300 es
precision highp float;in vec2 uv;in vec3 frame;in vec4 tone;in float height;uniform sampler2D baseTex;uniform float cut;uniform float additive;
uniform bool spriteCard;uniform bool blendFrames;uniform bool mod2x;uniform float overbright;uniform float addSelf;layout(location=0)out vec4 color;layout(location=1)out vec4 glow;
uniform highp sampler2D sceneDepth;uniform vec2 depthProjection;uniform float depthBlendScale;
vec4 cardSample(vec2 p){vec4 s=texture(baseTex,p);s.rgb=mix(pow((s.rgb+.055)/1.055,vec3(2.4)),s.rgb/12.92,lessThanEqual(s.rgb,vec3(.04045)));return s;}
void main(){
 if(height>cut)discard;
 if(!spriteCard){vec4 tex=texture(baseTex,uv)*tone;color=vec4(pow(max(tex.rgb,vec3(0.0)),vec3(2.2)),tex.a);glow=vec4(color.rgb*additive,color.a);return;}
 vec4 tex=cardSample(uv);if(blendFrames)tex=mix(tex,cardSample(frame.xy),frame.z);
 vec3 rgb=tex.rgb*overbright,tint=pow(max(tone.rgb,vec3(0.0)),vec3(2.2));float alpha=tex.a*tone.a;
 if(depthBlendScale>0.0){
  float scene=texelFetch(sceneDepth,ivec2(gl_FragCoord.xy),0).r;if(gl_FragCoord.z>=scene)discard;
  // Convert the window-depth difference to distance along the camera axis.
  if(scene<1.0){float dz=2.0*(scene-gl_FragCoord.z)/(gl_FragCoord.w*(depthProjection.x+2.0*(1.0-scene)*depthProjection.y));alpha*=clamp(dz/depthBlendScale,0.0,1.0);}
 }
 if(mod2x){color=vec4(mix(vec3(.5),rgb,tint*alpha),alpha);glow=color;return;}
 rgb*=tint;if(addSelf!=0.0)rgb*=alpha*(1.0+addSelf);
 color=vec4(rgb,alpha);glow=vec4(rgb*(addSelf!=0.0?1.0:additive),alpha);
}`);
		// Trails: static per-actor ribbons; time window and fade are uniforms.
		this.trailProgram = this.program(`#version 300 es
layout(location=0) in vec3 position;layout(location=1) in vec2 info;uniform mat4 view;out vec2 vInfo;out float vZ;
void main(){vInfo=info;vZ=position.z;gl_Position=view*vec4(position,1.0);}`, `#version 300 es
precision highp float;in vec2 vInfo;in float vZ;uniform float now;uniform float span;uniform vec3 tone;uniform float cut;uniform float strength;layout(location=0) out vec4 color;layout(location=1) out vec4 glow;
void main(){float age=now-vInfo.x;if(age<0.0||age>span||vZ>cut)discard;float f=1.0-age/span;float edge=1.0-abs(vInfo.y);
 float a=(.12+.88*f*f)*smoothstep(0.0,.45,edge)*strength;vec3 c=mix(tone,vec3(1.0),pow(f,8.0)*.55)*(.9+.6*f);
 color=vec4(c,a);glow=vec4(tone*a*(.25+.75*pow(f,3.0)),1.0);}`);
		const post = `#version 300 es
out vec2 uv;void main(){vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);uv=p;gl_Position=vec4(p*2.0-1.0,0.0,1.0);}`;
		if (this.hdr) this.poseProgram = this.program(`#version 300 es
layout(location=0) in vec2 corner;layout(location=1) in vec4 rows;layout(location=2) in vec3 tree;
uniform float height;flat out vec2 offsets;flat out vec3 bases;
void main(){offsets=rows.zw-rows.xx;bases=tree;gl_Position=vec4(corner.x*2.-1.,(rows.x+corner.y*rows.y)*2./height-1.,0.,1.);}`, `#version 300 es
precision highp float;precision highp int;uniform highp sampler2D poseA,poseB;
flat in vec2 offsets;flat in vec3 bases;out vec4 column;
void main(){int y=int(gl_FragCoord.y),a=y+int(offsets.x),b=y+int(offsets.y);float blend=bases.z;
vec4 v=texelFetch(poseA,ivec2(2+int(gl_FragCoord.x),a),0);
for(;;){
vec4 q=texelFetch(poseA,ivec2(0,a),0),r=texelFetch(poseB,ivec2(0,b),0);float d=dot(q,r);if(d<0.)r=-r;
d=clamp(abs(d),0.,1.);if(d>.99999)q=normalize(mix(q,r,blend));else{float theta=acos(d);q=(q*sin((1.-blend)*theta)+r*sin(blend*theta))/sin(theta);}
vec4 ps=mix(texelFetch(poseA,ivec2(1,a),0),texelFetch(poseB,ivec2(1,b),0),blend);
vec3 rot=v.xyz+2.*cross(q.xyz,cross(q.xyz,v.xyz)+q.w*v.xyz);
v.xyz=rot*ps.w+ps.xyz*v.w;int parent=int(texelFetch(poseA,ivec2(6,a),0).x);if(parent<0)break;
a=int(bases.x)+parent;b=int(bases.y)+parent;}column=v;}`);
		this.downsampleProgram = this.program(post, `#version 300 es
precision highp float;in vec2 uv;uniform sampler2D source;uniform vec2 stepSize;uniform float prefilter;out vec4 color;
vec3 bright(vec2 p){vec3 c=texture(source,p).rgb;if(prefilter>.5){float b=max(c.r,max(c.g,c.b)),knee=clamp(b-.05,0.0,.5);c*=max(b-.3,knee*knee)/max(b,.0001);}return c;}
void main(){color=vec4((bright(uv+stepSize*vec2(-.5,-.5))+bright(uv+stepSize*vec2(.5,-.5))+bright(uv+stepSize*vec2(-.5,.5))+bright(uv+stepSize*vec2(.5,.5)))*.25,1.0);}`);
		this.blurProgram = this.program(post, `#version 300 es
precision highp float;in vec2 uv;uniform sampler2D source;uniform vec2 stepSize;out vec4 color;
void main(){vec3 c=texture(source,uv).rgb*.227027;c+=(texture(source,uv+stepSize*1.384615).rgb+texture(source,uv-stepSize*1.384615).rgb)*.316216;c+=(texture(source,uv+stepSize*3.230769).rgb+texture(source,uv-stepSize*3.230769).rgb)*.070270;color=vec4(c,1.0);}`);
		this.aoProgram = this.program(post, `#version 300 es
precision highp float;in vec2 uv;uniform highp sampler2D depthTex;uniform sampler2D gbufTex;uniform mat4 inverseView;uniform vec3 eye;uniform vec2 screen;uniform float pixelScale;out vec4 color;
vec3 position(vec2 p,float d){vec4 v=inverseView*vec4(p*2.0-1.0,d*2.0-1.0,1.0);return v.xyz/v.w;}
void main(){float d=texture(depthTex,uv).r;vec4 g=texture(gbufTex,uv);if(d>=1.0||g.a<.25){color=vec4(1.0);return;}
 vec3 p=position(uv,d),n=normalize(g.xyz*2.0-1.0);float radius=clamp(34.0*pixelScale/max(length(eye-p),1.0),2.0,60.0);
 float noise=fract(52.9829189*fract(dot(gl_FragCoord.xy,vec2(.06711056,.00583715))))*6.2831;float occ=0.0;
 for(int i=0;i<10;i++){float a=float(i)*2.399963+noise;vec2 q=uv+vec2(cos(a),sin(a))*sqrt((float(i)+.5)/10.0)*radius/screen;
  float z=texture(depthTex,q).r;if(z>=1.0)continue;vec3 delta=position(q,z)-p;float dist=length(delta);
  occ+=max(dot(n,delta/max(dist,.001))-.1,0.0)*(1.0-smoothstep(10.0,48.0,dist));}
 color=vec4(vec3(clamp(1.0-occ*.24,0.0,1.0)),1.0);}`);
		this.compositeProgram = this.program(post, `#version 300 es
precision highp float;in vec2 uv;
uniform sampler2D colorTex;uniform highp sampler2D depthTex;uniform sampler2D gbufTex;uniform sampler2D aoTex;
uniform mat4 inverseView;uniform mat4 inverseSky;uniform bool flatSky;uniform vec3 eye;uniform vec2 screen;uniform float outlinePx;uniform vec2 fx;uniform float ortho;uniform float toonOn;out vec4 color;
// Painterly sky for toon: luminance in soft-edged bands, more saturation.
vec3 paintSky(vec3 s){float l=dot(s,vec3(.2126,.7152,.0722)),g=sqrt(max(l,0.0))*9.0,q=(floor(g)+smoothstep(.35,.65,fract(g)))/9.0;return max(mix(vec3(l),s,1.35),vec3(0.0))*q*q/max(l,1e-6);}
uniform vec3 sunPosition;uniform float daylight;uniform vec3 environmentColor;uniform vec3 fogColor;uniform vec3 fogRange;uniform vec3 viewForward;
uniform sampler2D skyRight;uniform sampler2D skyLeft;uniform sampler2D skyBack;uniform sampler2D skyFront;uniform sampler2D skyUp;uniform sampler2D skyDown;uniform float mapSky;uniform float skyEncoding[6];uniform vec3 skyTransform[12];uniform vec3 skyTint[6];
vec3 position(vec2 p,float d){vec4 v=inverseView*vec4(p*2.0-1.0,d*2.0-1.0,1.0);return v.xyz/v.w;}
vec3 skyTexel(sampler2D source,ivec2 p,ivec2 size){vec4 value=texelFetch(source,clamp(p,ivec2(0),size-1),0);return value.rgb*value.a*8.0;}
vec3 sampleSky(sampler2D source,int face,vec2 uv){vec3 q=vec3(uv,1.0);vec2 p=vec2(dot(skyTransform[face*2],q),dot(skyTransform[face*2+1],q));vec3 c;
 if(skyEncoding[face]>1.5){ivec2 size=textureSize(source,0);vec2 pixel=p*vec2(size)-.5;ivec2 at=ivec2(floor(pixel));vec2 f=fract(pixel);c=mix(mix(skyTexel(source,at,size),skyTexel(source,at+ivec2(1,0),size),f.x),mix(skyTexel(source,at+ivec2(0,1),size),skyTexel(source,at+ivec2(1,1),size),f.x),f.y);}
 else{c=texture(source,p).rgb;if(skyEncoding[face]<.5)c=pow(max(c,vec3(0.0)),vec3(2.2));}return c*skyTint[face];}
vec3 sourceSky(vec3 r){vec3 a=abs(r);vec2 p;if(a.x>=a.y&&a.x>=a.z){p=vec2(r.x>0.0?-r.y:r.y,-r.z)/a.x*.5+.5;return r.x>0.0?sampleSky(skyRight,0,p):sampleSky(skyLeft,1,p);}if(a.y>=a.z){p=vec2(r.y>0.0?r.x:-r.x,-r.z)/a.y*.5+.5;return r.y>0.0?sampleSky(skyBack,2,p):sampleSky(skyFront,3,p);}p=vec2(r.x,r.z>0.0?r.y:-r.y)/a.z*.5+.5;return r.z>0.0?sampleSky(skyUp,4,p):sampleSky(skyDown,5,p);}
float viewDistance(vec2 p,float d){return d>=1.0?1e6:length(position(p,d)-eye);}
void main(){float d=texture(depthTex,uv).r;vec4 g=texture(gbufTex,uv),sceneColor=texture(colorTex,uv);vec3 c=sceneColor.rgb;
 if(d>=1.0){
  vec4 skyFar=inverseSky*vec4(uv*2.0-1.0,1,1),skyNear=inverseSky*vec4(uv*2.0-1.0,-1,1);vec3 ray=normalize(skyFar.xyz/skyFar.w-skyNear.xyz/skyNear.w);
  vec3 skyTop=mix(vec3(.001,.003,.012),vec3(.035,.06,.12),daylight),skyMid=mix(vec3(.007,.012,.03),vec3(.10,.15,.24),daylight),skyLow=mix(vec3(.02,.026,.045),vec3(.42,.33,.30),daylight);
  float h=ray.z;vec3 sky=mix(skyMid,skyTop,smoothstep(.05,.7,h));sky=mix(skyLow,sky,smoothstep(-.25,.12,h));
  if(mapSky>.5)sky=sourceSky(ray);else if(mapSky<-.5)sky=environmentColor;
  if(toonOn>.5)sky=paintSky(sky);
  float sun=smoothstep(.99990,.99996,dot(ray,sunPosition)),moon=smoothstep(.99988,.99995,dot(ray,-sunPosition));if(abs(mapSky)<.5)sky+=vec3(3.0,2.5,1.8)*sun*daylight+vec3(.45,.52,.7)*moon*(1.0-daylight);c+=(flatSky?vec3(.05,.07,.11):sky)*(1.0-sceneColor.a);
 }else{
  float dist=viewDistance(uv,d);vec3 n=normalize(g.xyz*2.0-1.0);
  // Ink: depth discontinuities, normal creases and object-mask boundaries; thicker and
  // darker on characters, thinner and fading with distance on the world.
  float edge=0.0,charEdge=0.0,nearD=d;vec2 o=outlinePx/screen;vec3 nearC=c;
  vec2 taps[8]=vec2[8](vec2(1,0),vec2(-1,0),vec2(0,1),vec2(0,-1),vec2(.7,.7),vec2(-.7,.7),vec2(.7,-.7),vec2(-.7,-.7));
  for(int i=0;i<8;i++){vec2 q=uv+taps[i]*o;float dq=texture(depthTex,q).r;vec4 gq=texture(gbufTex,q);
   float dd=abs(viewDistance(q,dq)-dist)/max(dist,1.0);float e=smoothstep(.012,.035,dd);
   if(gq.a>.25&&g.a>.25)e=max(e,smoothstep(.30,.60,1.0-dot(n,normalize(gq.xyz*2.0-1.0)))*.85);
   float mb=step(.2,abs(gq.a-g.a))*step(.75,max(gq.a,g.a));charEdge=max(charEdge,mb);
   if(max(gq.a,g.a)>.75)charEdge=max(charEdge,e);edge=max(edge,e);if(dq<nearD){nearD=dq;nearC=texture(colorTex,q).rgb;}}
  float far=1.0-smoothstep(1400.0,5200.0,dist)*.75;
  // Opaque ink (user 2026-11-18): saturates within the edge instead of a partial darkening, in a
  // dark shade of the object in front, so a character's outline follows its own colours.
  float ink=clamp(max(edge*far*1.6,charEdge*2.5)*fx.x,0.0,1.0);vec3 inkColor=nearC*.2;
  float ao=texture(aoTex,uv).r;
  ao=fx.y>.5?ao:1.0;c*=mix(.60,1.0,ao);
  c=mix(c,inkColor,ink);
  float fogDistance=dot(position(uv,d)-eye,viewForward),fog=clamp(min(fogRange.z,(fogDistance-fogRange.x)/max(1.0,fogRange.y-fogRange.x)),0.0,1.0)*(1.0-ortho);c=mix(c,fogColor,min(fog*fog,toonOn>.5?.7:1.0));
 }
 color=vec4(c,1.0);}`);
		// L4D2's 16 linear-luminance bins and exposure history stay on the GPU.
		this.histogramProgram = this.program(post, `#version 300 es
precision highp float;precision highp int;uniform sampler2D source;uniform sampler2D exposureTex;uniform int initial;
layout(location=0)out vec4 bins0;layout(location=1)out vec4 bins1;layout(location=2)out vec4 bins2;layout(location=3)out vec4 bins3;
void main(){float bins[16];for(int i=0;i<16;i++)bins[i]=0.0;ivec2 size=textureSize(source,0),origin=ivec2(gl_FragCoord.xy)*4;float exposure=initial==1?1.0:texelFetch(exposureTex,ivec2(0),0).r;
 for(int y=0;y<4;y++)for(int x=0;x<4;x++){ivec2 p=origin+ivec2(x,y);if(any(greaterThanEqual(p,size)))continue;vec2 uv=(vec2(p)+.5)/vec2(size);if(any(greaterThan(abs(uv-.5),vec2(.45,.425))))continue;
  float lum=max(0.0,dot(texelFetch(source,p,0).rgb,vec3(.2125,.7154,.0721))*exposure);int bin=min(15,int(pow(min(lum,1.0),.4)*16.0));bins[bin]+=.0625;}
 bins0=vec4(bins[0],bins[1],bins[2],bins[3]);bins1=vec4(bins[4],bins[5],bins[6],bins[7]);bins2=vec4(bins[8],bins[9],bins[10],bins[11]);bins3=vec4(bins[12],bins[13],bins[14],bins[15]);}`);
		this.histogramReduceProgram = this.program(post, `#version 300 es
precision highp float;uniform sampler2D source0;uniform sampler2D source1;uniform sampler2D source2;uniform sampler2D source3;
layout(location=0)out vec4 bins0;layout(location=1)out vec4 bins1;layout(location=2)out vec4 bins2;layout(location=3)out vec4 bins3;
void main(){bins0=vec4(0.0);bins1=vec4(0.0);bins2=vec4(0.0);bins3=vec4(0.0);ivec2 size=textureSize(source0,0),origin=ivec2(gl_FragCoord.xy)*4;
 for(int y=0;y<4;y++)for(int x=0;x<4;x++){ivec2 p=origin+ivec2(x,y);if(any(greaterThanEqual(p,size)))continue;bins0+=texelFetch(source0,p,0)*.0625;bins1+=texelFetch(source1,p,0)*.0625;bins2+=texelFetch(source2,p,0)*.0625;bins3+=texelFetch(source3,p,0)*.0625;}}`);
		this.exposureProgram = this.program(post, `#version 300 es
precision highp float;uniform sampler2D source0;uniform sampler2D source1;uniform sampler2D source2;uniform sampler2D source3;uniform sampler2D previous;
uniform vec3 parameters;uniform vec2 limits;uniform float elapsed;uniform int history;out vec4 color;
float bins[16];float total;
float location(float percent,float target){float above=0.0;for(int i=15;i>=0;i--){float amount=bins[i]/total,lo=pow(float(i)/16.0,2.5),hi=pow(float(i+1)/16.0,2.5),needed=percent-above;if(amount>0.0&&needed<=amount){if(target>=lo&&target<=hi)return target;return clamp(hi-needed/amount*(hi-lo),lo,hi);}above+=amount;}return -1.0;}
void main(){int x=int(gl_FragCoord.x);if(x>0&&x<10){color=history==0?vec4(1.0):texelFetch(previous,ivec2(x+1,0),0);return;}
 vec4 a=texelFetch(source0,ivec2(0),0),b=texelFetch(source1,ivec2(0),0),c=texelFetch(source2,ivec2(0),0),d=texelFetch(source3,ivec2(0),0);total=0.0;
 for(int i=0;i<4;i++){bins[i]=a[i];bins[i+4]=b[i];bins[i+8]=c[i];bins[i+12]=d[i];total+=a[i]+b[i]+c[i]+d[i];}
 float current=history==0?1.0:texelFetch(previous,ivec2(0),0).r,goal=current;
 if(total>0.0){float bright=location(parameters.y,parameters.x),median=location(.5,-1.0);if(bright<0.0)bright=parameters.x;float factor=parameters.x/max(.0001,bright);if(median>0.0)factor=max(factor,parameters.z/median);goal=max(.001,clamp(current*factor,limits.x,limits.y));}
 if(x==10){color=vec4(goal);return;}
 if(history>=9){float average=goal*.8;for(int i=0;i<9;i++)average+=texelFetch(previous,ivec2(i+2,0),0).r*abs(float(i)-5.0)*.2;goal=clamp(average*.2,limits.x,limits.y);}
 float rate=2.0;if(goal<current)rate=min(6.0,rate+(current-goal)*4.0*(2.0/3.0));float fraction=clamp(rate*elapsed,0.0,1.0/64.0);color=vec4(mix(current,goal,fraction));}`);
		this.tonemapProgram = this.program(post, `#version 300 es
precision highp float;in vec2 uv;uniform sampler2D source;uniform sampler2D exposureTex;uniform sampler2D bloom0;uniform sampler2D bloom1;uniform sampler2D bloom2;uniform sampler2D bloom3;uniform sampler2D overlayTex;uniform highp sampler2D depthTex;uniform sampler2D gbufTex;uniform mat4 inverseView;uniform int ringCount;uniform vec4 ringSphere[4];uniform vec3 ringTone[4];uniform vec2 effects;out vec4 color;
uniform highp sampler2D coverageTex;uniform int coverageRows;uniform float toonGrade;
vec3 position(vec2 p,float d){vec4 v=inverseView*vec4(p*2.0-1.0,d*2.0-1.0,1.0);return v.xyz/v.w;}
void main(){vec3 c=texture(source,uv).rgb+(texture(bloom0,uv).rgb*.42+texture(bloom1,uv).rgb*.26+texture(bloom2,uv).rgb*.17+texture(bloom3,uv).rgb*.10)*effects.x;c*=texelFetch(exposureTex,ivec2(0),0).r;vec2 v=uv-.5;c*=1.0-dot(v,v)*effects.y;
 // Materials and sky already carry the toon palette; keep the final grade restrained.
 if(toonGrade>.5){c=c*1.4/(1.0+c*.32);vec3 gc=pow(clamp(c,0.0,1.0),vec3(1.0/2.2));float l=dot(gc,vec3(.2126,.7152,.0722)),x=l*5.0,q=(floor(x)+smoothstep(.15,.85,fract(x)))/5.0;
  float chroma=max(gc.r,max(gc.g,gc.b))-min(gc.r,min(gc.g,gc.b));vec3 graded=mix(vec3(l),gc,1.10+.26*(1.0-smoothstep(.2,.6,chroma)))*mix(1.0,max(q,.03)/max(l,.001),.32*smoothstep(.035,.24,l));
  float peak=max(graded.r,max(graded.g,graded.b));c=pow(clamp(graded*(1.0+.18*pow(1.0-clamp(peak,0.0,1.0),2.0)),0.0,1.0),vec3(2.2));}
 c=pow(clamp(c,0.0,1.0),vec3(1.0/2.2));float d=texture(depthTex,uv).r;vec4 g=texture(gbufTex,uv);
 if(d<1.0&&g.a<.55&&coverageRows>0){vec3 world=position(uv,d);vec2 distance=vec2(1e9);float aa=max(length(fwidth(world)),.15);
  for(int row=0;row<coverageRows;){vec4 lo=texelFetch(coverageTex,ivec2(0,row),0),hi=texelFetch(coverageTex,ivec2(1,row),0);int count=int(lo.w),kind=int(hi.w)-1;
   if(all(greaterThanEqual(world,lo.xyz))&&all(lessThanEqual(world,hi.xyz)))for(int n=1;n<=count;n++){vec4 flame=texelFetch(coverageTex,ivec2(0,row+n),0),hull=texelFetch(coverageTex,ivec2(1,row+n),0);vec2 side=max(abs(world.xy-flame.xy)-hull.z,0.0);float rise=world.z>flame.z?world.z-flame.z:max(flame.z-world.z-hull.w,0.0);distance[kind]=min(distance[kind],max(length(vec3(side,rise))-flame.w,world.z-hull.x-hull.y));}row+=count+1;}
  for(int kind=0;kind<2;kind++){float inside=1.0-step(0.0,distance[kind]),edge=1.0-smoothstep(1.5-aa,1.5+aa,-distance[kind]);vec3 tone=kind==0?vec3(162.0,216.0,73.0)/255.0:vec3(1.0,154.0/255.0,50.0/255.0);c=mix(c,tone,inside*mix(.26,.9,edge));}}
 vec4 overlay=texture(overlayTex,uv);c=c*(1.0-overlay.a)+overlay.rgb;
 if(d<1.0&&g.a<.55){vec3 world=position(uv,d);for(int i=0;i<4;i++){if(i>=ringCount)break;float edge=abs(length(world-ringSphere[i].xyz)-ringSphere[i].w),aa=max(fwidth(edge),.15);float line=1.0-smoothstep(.55-aa,.55+aa,edge),halo=exp(-edge*edge/24.0)*.16;c+=ringTone[i]*(line*.95+halo);}}
 color=vec4(clamp(c,0.0,1.0),1.0);}`);
		this.fxaaProgram = this.program(post, `#version 300 es
precision highp float;in vec2 uv;uniform sampler2D source;uniform vec2 texel;out vec4 color;
float luma(vec3 c){return dot(c,vec3(.299,.587,.114));}
void main(){vec3 m=texture(source,uv).rgb;float lm=luma(m),nw=luma(texture(source,uv+vec2(-1,-1)*texel).rgb),ne=luma(texture(source,uv+vec2(1,-1)*texel).rgb),sw=luma(texture(source,uv+vec2(-1,1)*texel).rgb),se=luma(texture(source,uv+vec2(1,1)*texel).rgb);
 float lo=min(lm,min(min(nw,ne),min(sw,se))),hi=max(lm,max(max(nw,ne),max(sw,se)));if(hi-lo<max(.04,hi*.12)){color=vec4(m,1.0);return;}
 vec2 dir=vec2(-((nw+ne)-(sw+se)),(nw+sw)-(ne+se));float reduce=max((nw+ne+sw+se)*.03125,1.0/128.0);dir=clamp(dir/(min(abs(dir.x),abs(dir.y))+reduce),vec2(-8.0),vec2(8.0))*texel;
 vec3 a=.5*(texture(source,uv+dir*(1.0/3.0-.5)).rgb+texture(source,uv+dir*(2.0/3.0-.5)).rgb),b=a*.5+.25*(texture(source,uv-dir*.5).rgb+texture(source,uv+dir*.5).rgb);
 float lb=luma(b);color=vec4((lb<lo||lb>hi)?a:b,1.0);}`);
	}

	// ---- World ------------------------------------------------------------------
	loadWorld(map) {
		const g = this.gl, groups = new Map();
		map.collision = map.world.filter(entry=>!entry.material?.sky && !this.transparent(entry.material)).map(entry=>{ const vertices = new Float32Array(entry.vertices.length/4); for (let i=0,o=0;i<entry.vertices.length;i+=12,o+=3) vertices.set(entry.vertices.subarray(i,i+3),o); return {vertices,bounds:entry.bounds,brush:!!entry.material?.brush}; });
		// One vertex buffer and VAO per material; its XY chunks are ranges in it, so the visible ones
		// go out as a single multi-draw (WEBGL_multi_draw) instead of one draw call per chunk.
		for (const entry of map.world) { if (!groups.has(entry.material)) groups.set(entry.material, []); groups.get(entry.material).push(entry); }
		this.multiDraw = g.getExtension('WEBGL_multi_draw');
		this.world = [...groups].map(([material, entries]) => {
			const total = entries.reduce((sum, entry) => sum + entry.vertices.length, 0), buffer = g.createBuffer(); this.buffers.push(buffer);
			g.bindBuffer(g.ARRAY_BUFFER, buffer); g.bufferData(g.ARRAY_BUFFER, total * 4, g.STATIC_DRAW);
			let offset = 0; const chunks = entries.map(entry => { g.bufferSubData(g.ARRAY_BUFFER, offset * 4, entry.vertices); const chunk = {first:offset / 12, count:entry.vertices.length / 12, bounds:entry.bounds || [-1e9,-1e9,-1e9,1e9,1e9,1e9]}; offset += entry.vertices.length; return chunk; });
			const vao = this.vao([[buffer, [[0,3,0],[1,3,12],[2,2,24],[3,3,32],[4,1,44]], 48]]);
			return {material, chunks, vao, firsts:new Int32Array(chunks.length), counts:new Int32Array(chunks.length), transparent:this.transparent(material), alphaTested:material?.values?.$alphatest === '1'};
		});
		this.world.sort((a, b) => Number(a.transparent) - Number(b.transparent) || Number(a.material.shader === 'water') - Number(b.material.shader === 'water'));
		let triangles = 0; for (const group of this.world) for (const chunk of group.chunks) triangles += chunk.count / 3; this.triangles = triangles;
		for (const entry of map.world) delete entry.vertices;
	}
	addModels(models) { Object.assign(this.models, models); }
	static planes(m) {
		const r = (i) => [m[i], m[4+i], m[8+i], m[12+i]], row0 = r(0), row1 = r(1), row2 = r(2), row3 = r(3), out = [];
		for (const [a, s] of [[row0,1],[row0,-1],[row1,1],[row1,-1],[row2,1],[row2,-1]]) { const p = row3.map((v, k) => v + s * a[k]); const n = Math.hypot(p[0], p[1], p[2]) || 1; out.push(p.map(v => v / n)); }
		return out;
	}
	static visible(planes, b) {
		for (const p of planes) if (p[0] * (p[0] > 0 ? b[3] : b[0]) + p[1] * (p[1] > 0 ? b[4] : b[1]) + p[2] * (p[2] > 0 ? b[5] : b[2]) + p[3] < 0) return false;
		return true;
	}
	// Uniform writes that repeat the value already in the program are skipped (materials mostly share
	// defaults; each GL call costs more than the comparison).
	uv(program, name, value) {
		const location = this.u(program, name); if (!location) return; const cache = this.uniformValues || (this.uniformValues = new Map()); let last = cache.get(location);
		if (typeof value === 'number') { if (last === value) return; cache.set(location, value); this.gl.uniform1f(location, value); return; }
		if (last && last.length === value.length) { let same = true; for (let i = 0; i < value.length; i++) if (last[i] !== Math.fround(value[i])) { same = false; break; } if (same) return; last.set(value); }
		else cache.set(location, last = Float32Array.from(value)); const g = this.gl; if (value.length === 4) g.uniform4fv(location, last); else if (value.length === 3) g.uniform3fv(location, last); else if (value.length === 2) g.uniform2fv(location, last); else g.uniform1fv(location, last);
	}
	makeRawSampler() { const g = this.gl, s = g.createSampler(); g.samplerParameteri(s, g.TEXTURE_COMPARE_MODE, g.NONE); g.samplerParameteri(s, g.TEXTURE_MIN_FILTER, g.NEAREST); g.samplerParameteri(s, g.TEXTURE_MAG_FILTER, g.NEAREST); g.samplerParameteri(s, g.TEXTURE_WRAP_S, g.CLAMP_TO_EDGE); g.samplerParameteri(s, g.TEXTURE_WRAP_T, g.CLAMP_TO_EDGE); return s; }
	static materialSlots = [[0,'baseTex','texture'],[1,'secondTex','second'],[2,'maskTex','mask'],[3,'emissionTex','emissive'],[6,'characterTex','gradient'],[7,'normalTex','normal'],[8,'expTex','exponent'],[9,'flowTex','flow'],[10,'lightmapTex','lightmap'],[13,'lightwarpTex','lightwarp']];
	static fixedNames = ['surface','lightmapOn','tintBlend','envControls','envTint','envFresnel','envBaseMask','water','waterTint','phong','phongExtra','phongTint','diffuseOptions','glowTint','options'];
	bindFixed(program, material, u) {
		const key = material || u, names = ReplayRenderer.fixedNames;
		let profile = this.materialProfiles.get(key);
		if (!profile) {
			const values = [u.surface,material?.lightmap ? 1 : 0,u.tintBlend,u.envControls || [0,0,1,0],u.envTint || [1,1,1],u.envFresnel || [0,1,2],u.envBaseMask || [1,0,1],u.water,u.waterTint,u.phong,u.phongExtra,u.phongTint,u.diffuse || [0,0,0,0],u.glow,u.options];
			const signature = JSON.stringify(values);
			profile = this.fixedProfiles.get(signature);
			if (!profile) this.fixedProfiles.set(signature, profile = {values, changes:new WeakMap()});
			this.materialProfiles.set(key, profile);
		}
		const previous = program.fixedProfile;
		if (previous === profile) return;
		if (!previous) { for (let i = 0; i < names.length; i++) this.uv(program, names[i], profile.values[i]); }
		else {
			let changes = profile.changes.get(previous);
			if (!changes) {
				changes = [];
				for (let i = 0; i < names.length; i++) {
					const a = profile.values[i], b = previous.values[i];
					if (typeof a === 'number' ? a !== b : a.some((v,k) => v !== b[k])) changes.push(i);
				}
				profile.changes.set(previous, changes);
			}
			for (const i of changes) this.uv(program, names[i], profile.values[i]);
		}
		program.fixedProfile = profile;
	}
	bindMaterialTexture(unit, target, texture) {
		if (this.unitBound[unit] === texture) return;
		const g = this.gl; g.activeTexture(g.TEXTURE0 + unit); g.bindTexture(target, texture); this.unitBound[unit] = texture;
	}
	bindMaterial(program, material) {
		const g = this.gl, v = material?.values || {}, alpha = this.entityAlpha*(material?.alphaByTeam?.[this.viewTeam] ?? 1);
		const cull = !(material?.twoSided || v.$nocull === '1' || material?.shader === 'water');
		if (this.materialCull !== cull) {
			this.materialCull = cull;
			if (cull) { g.enable(g.CULL_FACE); g.cullFace(g.BACK); g.frontFace(g.CCW); } else g.disable(g.CULL_FACE);
		}
		if (material && !material._u) { // parsed once per material
			const vector = (s, def) => { if (!s) return def; const a = String(s).match(/[-+]?\d*\.?\d+/g)?.map(Number); return a?.length >= 3 ? a.slice(0,3).map(x => s.includes('{') ? x / 255 : x) : def; };
			// Opaque Source materials also use alpha for tint, phong and self-illumination masks.
			material._u = {tint:material.shader === 'black' ? [0,0,0] : vector(v.$color2 || v.$color, [1,1,1]), glow:vector(v.$selfillumtint, [1,1,1]),
				options:[v.$selfillum === '1' ? 1 : 0, material.mask ? 1 : 0, v.$emissiveblendenabled === '1' ? ReplayRenderer.num(v.$emissiveblendstrength ?? 1) : 0, material.shader === 'unlitgeneric' || material.shader === 'black' ? 1 : 0],
				surface:[v.$alphatest === '1' ? ReplayRenderer.num(v.$alphatestreference || .5) : this.transparent(material) ? .01 : 0, this.transparent(material) ? 1 : 0, material.gradient ? 1 : 0, material.second ? 1 : 0]};
			const kind = /eye/.test(material.shader) ? 3 : 0;
			material._u.phong = [v.$phong === '1' ? ReplayRenderer.num(v.$phongboost ?? 1) : kind === 3 ? 1 : 0, ReplayRenderer.num(v.$phongexponent ?? v.$defaultphongexponent ?? 0), material.exponent ? 1 : 0, kind];
			material._u.phongExtra = [...vector(v.$phongfresnelranges, [0, .5, 1]), material.normal ? 1 : 0];
			material._u.phongTint = [...vector(v.$phongtint, [1, 1, 1]), v.$basemapalphaphongmask === '1' ? 2 : material.normal ? 1 : 0];
			material._u.diffuse = [v.$halflambert === '1' ? 1 : 0, material.lightwarp ? 1 : 0, ReplayRenderer.num(v.$phongexponentfactor ?? 0), v.$phongalbedotint === '1' && !v.$phongtint && material.exponent ? 1 : 0];
			material._u.envTint = vector(v.$envmaptint,[1,1,1]).map(value=>v.$phong === '1' || value>1 ? value : value**2.2);
			material._u.envFresnel = v.$phong === '1' ? vector(v.$phongfresnelranges,[0,.5,1]) : vector(v.$envmapfresnelminmaxexp,[0,1,2]);
			material._u.envBaseMask = vector(v.$basealphaenvmapmaskminmaxexp,[1,0,1]);
			material._u.envControls = [ReplayRenderer.num(v.$envmapfresnel || 0),ReplayRenderer.num(v.$envmapcontrast || 0),ReplayRenderer.num(v.$envmapsaturation ?? 1),v.$invertphongmask === '1' ? 1 : 0];
			const waterColor = (v.$refracttint || '{80 110 95}').match(/[\d.]+/g).slice(0,3).map(Number);
			// With water fog the body colour is the fog colour (c6m3: $fogcolor {9 7 1}, $fogend 30, so
			// nothing below the surface shows); $refracttint only tints the refracted view.
			const waterFog = v.$fogenable === '1' && v.$fogcolor ? v.$fogcolor.match(/[\d.]+/g).slice(0,3).map(Number) : null;
			material._u.waterTint = waterFog ? waterFog.map(x => (v.$fogcolor.includes('[') ? x : x / 255) ** 2.2 * 4) : waterColor.map(x => v.$refracttint?.includes('[') ? x : x / 255);
			material._u.water = [material.shader === 'water' ? 1 : 0, ReplayRenderer.num(v.$abovewater ?? 1), 0, 0];
			material._u.tintBlend = [v.$blendtintbybasealpha === '1' ? 1 : 0, ReplayRenderer.num(v.$blendtintcoloroverbase || 0)];
			material._u.animated = Number(v.proxies?.animatedtexture?.animatedtextureframerate || 0);
		}
		const u = material?._u || (this.defaultMaterialUniforms ||= {tint:[1,1,1], glow:[1,1,1], options:[0,0,0,0], surface:[0,0,0,0], phong:[0,0,0,0], phongExtra:[0,.5,1,0], phongTint:[1,1,1,0], waterTint:[80/255,110/255,95/255], water:[0,1,0,0], tintBlend:[0,0], animated:0});
		// Consecutive draws with the same material (e.g. a horde of common infected) keep its
		// textures and constant uniforms bound; only per-entity values are re-sent below.
		const key = material || u, same = this.boundMaterial === key && this.boundProgram === program && this.boundShadow === this.shadowPass && !this.actorSprite && !u.animated;
		this.boundMaterial = key; this.boundProgram = program; this.boundShadow = this.shadowPass;
		if (!program.samplersSet) {
			for (const [i, name] of ReplayRenderer.materialSlots) { if (this.shadowPass && i > 1) break; g.uniform1i(this.u(program, name), i); }
			if (!this.shadowPass) { g.uniform1i(this.u(program,'envmapTex'),11); g.uniform1i(this.u(program,'envmapMaskTex'),12); }
			program.samplersSet = true;
		}
		if (!same) for (const [i,,field] of ReplayRenderer.materialSlots) {
			if (this.shadowPass && i > 1) break;
			// Infected skin palettes and EyeRefract irises belong to mutually exclusive shaders.
			const image = material?.[field] || (i === 6 && material?.iris), raw = i === 9 && !image && this.settings.softShadows && this.settings.shadows;
			const texture = raw ? this.shadow.depth : image ? this.texture(image,i===0 && this.actorSprite ? this.actorSprite.frame ?? 0 : this.time*u.animated,i) : (i === 3 ? this.black : this.white);
			if (i === 9 && this.unitSampler !== raw) { this.unitSampler = raw; g.bindSampler(9, raw ? this.rawSampler || (this.rawSampler = this.makeRawSampler()) : null); }
			this.bindMaterialTexture(i, g.TEXTURE_2D, texture);
		}
		if (this.shadowPass) { if (!same) this.uv(program, 'surface', u.surface); return; }
		if (!same) this.bindFixed(program, material, u);
		this.uv(program, 'entityAlpha', alpha);
		let envmap = material?.envmap || (v.$envmap === 'env_cubemap' ? this.actorCube : null);
		// EyeRefract's $envmap is a cornea reflection masked to a small glint; unmasked it washed the whole eye white.
		if (/eye/.test(material?.shader || '')) envmap = null;
		if (material?.normal && v.$normalmapalphaenvmapmask !== '1' && (v.$basealphaenvmapmask === '1' || material.envmapMask)) envmap = null;
		if (!same || envmap !== this.boundEnvmap) {
			this.boundEnvmap = envmap;
			this.bindMaterialTexture(11, g.TEXTURE_CUBE_MAP, envmap?.faces ? this.texture(envmap,0,11) : this.blackCube);
			this.bindMaterialTexture(12, g.TEXTURE_2D, material?.envmapMask ? this.texture(material.envmapMask,0,12) : this.white);
			this.uv(program, 'envOptions', [envmap?.faces ? 1 : 0,envmap?.faces?.[0].float ? 1 : 0,v.$normalmapalphaenvmapmask === '1' ? 3 : material?.envmapMask ? 1 : v.$phong === '1' ? 4 : v.$basealphaenvmapmask === '1' ? 2 : 0,v.$phong === '1' ? 1 : 0]);
		}
		this.uv(program, 'skySurface', material?.sky || this.actorSky ? 1 : 0);
		// Common infected (Infected shader, gradient palette) carry a random m_clrRender; it is not a
		// diffuse multiplier for them (their ragdolls, which do not get it, look right), so it is ignored.
		this.uv(program, 'tint', this.actorTint && !material?.gradient && material?.shader !== 'infected' ? u.tint.map((v,k)=>v*this.actorTint[k]) : u.tint);
		const additive = v.$additive === '1' || [3,5,9].includes(this.actorRenderMode);
		// TransColor/TransTexture select entity render groups; full-alpha opaque materials still write depth.
		const blend = this.transparent(material) || alpha < 1 || additive, depthWrite = !blend || material?.shader === 'water';
		if (this.materialBlend !== blend) { this.materialBlend = blend; if (blend) g.enable(g.BLEND); else g.disable(g.BLEND); }
		if (blend && this.materialAdditive !== additive) { this.materialAdditive = additive; g.blendFuncSeparate(g.SRC_ALPHA,additive?g.ONE:g.ONE_MINUS_SRC_ALPHA,additive?g.ZERO:g.ONE,additive?g.ONE:g.ONE_MINUS_SRC_ALPHA); }
		if (this.materialDepthWrite !== depthWrite) { this.materialDepthWrite = depthWrite; g.depthMask(depthWrite); }
	}
	common(program, view) {
		const g = this.gl; g.useProgram(program); this.boundMaterial = null; this.boundEnvmap = undefined; this.boundLighting = this.boundLights = undefined; this.unitBound = []; if (this.unitSampler) { g.bindSampler(9, null); this.unitSampler = false; }
		// Outlines, particles and post-processing set their own raster state between passes.
		this.materialCull = this.materialBlend = this.materialAdditive = this.materialDepthWrite = undefined;
		g.uniformMatrix4fv(this.u(program, 'view'), false, view); g.uniform1f(this.u(program, 'cut'), this.cut);
		if (this.shadowPass) return;
		g.uniform1f(this.u(program, 'time'), this.time); g.uniform1f(this.u(program, 'daylight'), this.daylight);
		g.uniform1f(this.u(program, 'ambientOn'), 0); g.uniform1f(this.u(program, 'mapLight'), this.mapLighting ? 1 : 0); g.uniform1i(this.u(program, 'localCount'), 0);
		g.activeTexture(g.TEXTURE0 + 14); g.bindTexture(g.TEXTURE_2D, this.staticShadow.depth); g.uniform1i(this.u(program, 'staticShadowTex'), 14);
		g.uniform1i(this.u(program, 'flashlightCount'), this.flashlightCount);
		if (this.flashlightCount) {
			g.uniformMatrix4fv(this.u(program, 'flashlightView[0]'), false, this.flashlightViews);
			g.uniform3fv(this.u(program, 'flashlightOrigin[0]'), this.flashlightOrigins);
		}
		g.activeTexture(g.TEXTURE0 + 15); g.bindTexture(g.TEXTURE_2D, this.flashlightCookie); g.uniform1i(this.u(program, 'flashlightCookie'), 15);
		g.activeTexture(g.TEXTURE0 + 16); g.bindTexture(g.TEXTURE_2D, this.flashlightShadow.depth); g.uniform1i(this.u(program, 'flashlightDepth'), 16);
		this.uv(program, 'ownedItem', 0);
		g.uniform3fv(this.u(program,'skyFogColor'),this.skyFog?.color || [0,0,0]);g.uniform3fv(this.u(program,'skyFogRange'),this.skyFog ? [this.skyFog.start,this.skyFog.end,this.skyFog.density] : [0,1,0]);g.uniform3fv(this.u(program,'viewForward'),this.viewForward);
		g.uniform3fv(this.u(program, 'sunColor'), this.sunColor); g.uniform3fv(this.u(program, 'skyColor'), this.skyColor);
		g.uniform3fv(this.u(program, 'eye'), this.eye); g.uniform3fv(this.u(program, 'sunDir'), this.sunDir); g.uniform1f(this.u(program, 'realism'), 1); g.uniform1f(this.u(program, 'toonStyle'), this.settings.realism ? 0 : 1);
		g.uniformMatrix4fv(this.u(program, 'lightView'), false, this.lightView); g.uniform1f(this.u(program, 'shadowOn'), this.settings.shadows ? 1 : 0); g.uniform2fv(this.u(program, 'shadowSoft'), this.settings.shadows && this.settings.softShadows && this.shadowRadius ? [10, this.shadowRadius * 6 * .021 / (2 * this.shadowRadius / this.shadowSize)] : [0, 0]); g.uniform1f(this.u(program, 'shadowTexel'), 1 / this.shadowSize);
		g.activeTexture(g.TEXTURE0 + 4); g.bindTexture(g.TEXTURE_2D, this.shadow.depth); g.uniform1i(this.u(program, 'shadowTex'), 4);
	}
	drawWorld(planes, transparent, sky = false, alphaTested, view = this.shadowPass ? this.lightView : this.view) {
		const g = this.gl, program = this.shadowPass ? this.shadowWorld : this.worldProgram;
		this.common(program, view);
		this.actorSky = false; this.actorSprite = null; this.actorTint = null; this.actorCube = null; this.actorRenderMode = 0; this.entityAlpha = 1; this.uv(program, 'entityAlpha', 1);
		if (!this.shadowPass) this.uv(program, 'character', 0);
		let drawn = 0;
		for (const group of this.world) {
			if (group.transparent !== transparent || !!group.material?.sky !== sky || this.shadowPass && sky || alphaTested !== undefined && group.alphaTested !== alphaTested) continue;
			if (group.material?.alphaByTeam?.[this.viewTeam] <= 0) continue;
			if (transparent && !this.shadowPass) g.drawBuffers(group.material.shader === 'water' ? [g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1, g.COLOR_ATTACHMENT2] : [g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1]);
			let visible = 0;
			for (const chunk of group.chunks) {
				if (!ReplayRenderer.visible(planes, chunk.bounds) || !group.material?.sky && chunk.bounds[2] > this.cut) continue;
				group.firsts[visible] = chunk.first; group.counts[visible] = chunk.count; visible++; drawn += chunk.count;
			}
			if (!visible) continue;
			this.bindMaterial(program, group.material); g.bindVertexArray(group.vao);
			if (this.multiDraw && visible > 1) this.multiDraw.multiDrawArraysWEBGL(g.TRIANGLES, group.firsts, 0, group.counts, 0, visible);
			else for (let i = 0; i < visible; i++) g.drawArrays(g.TRIANGLES, group.firsts[i], group.counts[i]);
		}
		g.bindVertexArray(null); g.depthMask(true); g.disable(g.BLEND);
		return drawn;
	}

	// ---- Models -----------------------------------------------------------------
	meshFor(path) {
		const g = this.gl, model = this.models[path]; if (!model) return null;
		if (!this.meshes.has(path)) {
			const remap = new Map(model.used.map((id, i) => [id, i]));
			const root = model.bones[model.used[0]]; model.lightingOrigin = root ? Array.from(SourceModel.inverse(SourceModel.rows(root.inverse)).subarray(12,15)) : [0,0,0];
			this.meshes.set(path, model.groups.map(group => {
				const count = group.vertices.length / 3, array = new Float32Array(count * 14);
				for (let i = 0; i < count; i++) { const o = i * 14; array.set(group.vertices.subarray(i*3, i*3+3), o); array.set(group.normals.subarray(i*3, i*3+3), o+3); array[o+6] = group.uv[i*2]; array[o+7] = group.uv[i*2+1]; array.set(group.weights.subarray(i*3, i*3+3), o+8); for (let k = 0; k < 3; k++) array[o+11+k] = remap.get(group.bones[i*3+k]) ?? 0; }
				const bindings = [[this.buffer(array), [[0,3,0],[1,3,12],[2,2,24],[3,3,32],[4,3,44]], 56]];
				if (group.lighting) bindings.push([this.buffer(group.lighting),[[5,3,0]],12]);
				const vao = this.vao(bindings, this.buffer(group.indices, g.ELEMENT_ARRAY_BUFFER));
				const mesh = {group, vao, count:group.indices.length, type:group.indices instanceof Uint16Array ? g.UNSIGNED_SHORT : g.UNSIGNED_INT};
				for (const key of ['vertices','normals','uv','weights','bones','indices','lighting']) delete group[key];
				return mesh;
			}));
		}
		return this.meshes.get(path);
	}
	// Eyeball state for one actor and eyeball (studiorender R_StudioEyeballPosition): origin and up
	// from the eyeball's bone, look direction from the recorded eye angles (players) kept within 35
	// degrees of the head's forward, eyes slightly diverged by zoffset, iris projection scaled by
	// iris_scale. Bone world = skinning matrix * bind pose.
	eyeball(actor, model, index) {
		const key = index, cache = actor.eyes || (actor.eyes = []); if (cache[key] !== undefined) return cache[key];
		const ball = model.eyeballs?.[index], slot = ball ? model.used.indexOf(ball.bone) : -1; if (!ball || slot < 0 || actor.sky) return cache[key] = null;
		if (!ball.model) { const bind = SourceModel.inverse(SourceModel.rows(model.bones[ball.bone].inverse)); ball.model = {org:ReplayRenderer.point(bind, ball.org), up:ReplayRenderer.normalize(ReplayRenderer.point(bind, ball.up, 0)), forward:ReplayRenderer.normalize(ReplayRenderer.point(bind, ball.forward, 0)), head:Array.from(bind.subarray(12, 15))}; }
		const skin = actor.posePair ? actor.posePair.skinAt(slot) : actor.matrices.subarray(slot * 16, slot * 16 + 16), org = ReplayRenderer.point(skin, ball.model.org), head = ReplayRenderer.point(skin, ball.model.head);
		let up = ReplayRenderer.normalize(ReplayRenderer.point(skin, ball.model.up, 0)), face = ReplayRenderer.normalize(ReplayRenderer.point(skin, ball.model.forward, 0));
		if (face.reduce((sum, v, k) => sum + v * (org[k] - head[k]), 0) < 0) face = face.map(v => -v);
		let forward = face;
		if (actor.look) { const p = actor.look[0] * Math.PI / 180, y = actor.look[1] * Math.PI / 180, look = [Math.cos(p) * Math.cos(y), Math.cos(p) * Math.sin(y), -Math.sin(p)], c = look.reduce((sum, v, k) => sum + v * face[k], 0); const t = c >= .82 ? 1 : Math.max(0, (c + .2) / 1.02); forward = ReplayRenderer.normalize(face.map((v, k) => v + (look[k] - v) * t)); }
		const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
		let right = ReplayRenderer.normalize(cross(forward, up)); forward = ReplayRenderer.normalize(forward.map((v, k) => v + right[k] * ball.zoffset * 2));
		right = ReplayRenderer.normalize(cross(forward, up)); up = ReplayRenderer.normalize(cross(right, forward));
		const scale = ball.irisScale > 0 ? ball.irisScale : 1;
		return cache[key] = {org, forward, right:right.map(v => -v * scale), up:up.map(v => -v * scale)};
	}
	poseSlot(sample) {
		const old = sample.slot; if (old && old.tag === old.page.tag) return old;
		const g=this.gl, rows=sample.palette.length/28, pages=this.posePages;
		let page=pages.find(p=>p.key===sample.pageKey && p.used+rows<=p.height);
		if (!page) {
			page=pages.find(p=>p.key!==sample.pageKey && p.height>=rows);
			if (!page) {
				const texture=g.createTexture(), height=Math.max(2048,rows); this.textures.push(texture); g.bindTexture(g.TEXTURE_2D,texture);
				g.texStorage2D(g.TEXTURE_2D,1,g.RGBA32F,7,height); g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MIN_FILTER,g.NEAREST); g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MAG_FILTER,g.NEAREST);
				pages.push(page={texture,height,tag:0});
			}
			page.key=sample.pageKey; page.used=0; page.tag++;
		}
		const start=page.used; page.used+=rows; g.bindTexture(g.TEXTURE_2D,page.texture);
		g.texSubImage2D(g.TEXTURE_2D,0,0,start,7,rows,g.RGBA,g.FLOAT,sample.palette);
		return sample.slot={page,start,tag:page.tag};
	}
	uploadBones(actors) {
		let rows = 0; for (const actor of actors) if (!actor.posePair) { actor.boneOffset = rows; rows += actor.matrices.length / 16; }
		const cpuRows = rows, batches = [], g = this.gl;
		g.activeTexture(g.TEXTURE2);
		for (const actor of actors) if (actor.posePair) {
			const {a,b,blend,first,count:n}=actor.posePair, left=this.poseSlot(a), right=this.poseSlot(b);
			let batch=batches.find(v=>v.left===left.page && v.right===right.page);
			if (!batch) batches.push(batch={left:left.page,right:right.page,blend,actors:[]});
			actor.boneOffset=rows; batch.actors.push({rows,n,left:left.start,right:right.start,first,blend}); rows+=n;
		}
		if (rows > this.boneCapacity) { let capacity = this.boneCapacity; while (capacity < rows) capacity *= 2; this.allocateBones(capacity); }
		if (cpuRows) {
			if (!this.boneData || this.boneData.length < cpuRows*16) this.boneData=new Float32Array(this.boneCapacity*16);
			for (const actor of actors) if (!actor.posePair) this.boneData.set(actor.matrices,actor.boneOffset*16);
			g.bindTexture(g.TEXTURE_2D,this.boneTexture); g.texSubImage2D(g.TEXTURE_2D,0,0,0,4,cpuRows,g.RGBA,g.FLOAT,this.boneData,0);
		}
		if (!batches.length) return;
		const p=this.poseProgram; g.bindFramebuffer(g.FRAMEBUFFER,this.poseTarget); g.viewport(0,0,4,this.boneCapacity);
		g.disable(g.DEPTH_TEST); g.disable(g.BLEND); g.disable(g.CULL_FACE); g.useProgram(p); g.bindVertexArray(this.poseVao); g.bindBuffer(g.ARRAY_BUFFER,this.poseBuffer);
		g.uniform1f(this.u(p,'height'),this.boneCapacity);
		for (const batch of batches) {
			const count=batch.actors.length; if (!this.poseArgs || this.poseArgs.length<count*7) this.poseArgs=new Float32Array(count*7);
			let i=0; for(const actor of batch.actors){this.poseArgs[i++]=actor.rows;this.poseArgs[i++]=actor.n;this.poseArgs[i++]=actor.left+actor.first;this.poseArgs[i++]=actor.right+actor.first;this.poseArgs[i++]=actor.left;this.poseArgs[i++]=actor.right;this.poseArgs[i++]=actor.blend;}
			g.bufferData(g.ARRAY_BUFFER,this.poseArgs,g.STREAM_DRAW,0,i); this.bind(p,[['poseA',batch.left.texture],['poseB',batch.right.texture]]);
			g.drawArraysInstanced(g.TRIANGLE_STRIP,0,4,count);
		}
		g.bindVertexArray(null); g.bindFramebuffer(g.FRAMEBUFFER,null);
	}
	isDiagnostic(program) { return program === this.xrayProgram || program === this.hullProgram; }
	modelCommands(actor) {
		const model = this.models[actor.path]; if (!model) return [];
		const cache = model.drawCommands ||= new Map(), key = (actor.body || 0) + ':' + (actor.skin || 0);
		let commands = cache.get(key); if (commands) return commands;
		commands = []; commands.byMesh = [];
		for (const [index,mesh] of this.meshFor(actor.path).entries()) {
			const group = mesh.group;
			if (group.base && Math.floor((actor.body || 0) / group.base) % group.variants !== group.variant) continue;
			const material = ReplayRenderer.modelMaterial(model, group, actor.skin || 0);
			if (material?.visible !== false) commands.push(commands.byMesh[index] = {mesh, material, blended:this.transparent(material)});
		}
		cache.set(key, commands); return commands;
	}
	actorLighting(actor) {
		const model = this.models[actor.path]; let origin = ReplayRenderer.point(actor.posePair ? actor.posePair.skinAt(0) : actor.matrices, model.lightingOrigin);
		if (actor.sky) origin = origin.map((v,k)=>v/this.skyScale+this.map.sky.origin[k]);
		// The ambient cube, local world lights and nearest cubemap are shared per four-unit cell.
		const cache = this.ambientCache ||= new Map(), key = Math.round(origin[0]/4)+','+Math.round(origin[1]/4)+','+Math.round(origin[2]/4)+(actor.sky?'s':'');
		let cell = cache.get(key); if (cell) return cell;
		if (cache.size > 8192) cache.clear(); let cube = this.map.cubemapDefault, best = Infinity;
		for (const sample of this.map.cubemaps) { const dx=sample.origin[0]-origin[0], dy=sample.origin[1]-origin[1], dz=sample.origin[2]-origin[2], d=dx*dx+dy*dy+dz*dz; if (d < best) { best=d; cube=sample.texture; } }
		cell={lighting:ReplayRenderer.modelLighting(this.map, origin, !actor.sky),cube}; cache.set(key,cell); return cell;
	}
	prepareCommands(frame,states,next,owners,manifest) {
		if (!frame.draws) return null;
		const slots=new Map(),make=ids=>{const members=ids.slice(1).map(id=>{
			let slot=slots.get(id);if(slot)return slot;
			const s=states.get(id),color=s.render.color,path=manifest.models[s.model].path;
			const record={id,path,body:s.body,skin:s.skin,item:s.kind!=='actor',ownedItem:owners.has(id),look:s.eye?.angles||null,renderMode:s.render.mode};
			if(this.meshes.has(path))record.commands=this.modelCommands(record);
			const other=next.get(id),moving=other?.origin && s.origin?.some((v,i)=>v!==other.origin[i]);
			const sky=!s.origin || moving || s.parent || record.ownedItem || s.render.sprite?.attached ? null : SourceMap.inSky(this.map,s.origin);
			slots.set(id,slot={record,actor:null,sky,tint:[color&255,color>>>8&255,color>>>16&255].map(v=>v/255)});return slot;
		});return {mesh:ids[0],members};};
		const opaque=frame.draws.opaque.map(make);
		return {slots,opaque,sky:opaque.filter(b=>b.members.some(s=>s.sky!==false)),main:opaque.filter(b=>b.members.some(s=>!s.sky)),blended:frame.draws.blended.map(make),visible:[]};
	}
	frameCommands(actors, plan) {
		const opaque=plan?.opaque || [], transparent=[], extra=[];
		if(plan){for(const slot of plan.visible)slot.actor=null;plan.visible.length=0;}
		for(const actor of actors){
			actor.commands ||= this.modelCommands(actor);
			const slot=plan?.slots.get(actor.id);
			if(slot){slot.actor=actor;plan.visible.push(slot);}
			else if(!plan || actor.id==null)for(const command of actor.commands)(command.blended?transparent:extra).push({command,members:[{actor}]});
		}
		if(plan)for(const batch of plan.blended)if(batch.members[0].actor)transparent.push(batch);
		for(const batch of transparent){const a=batch.members[0].actor, m=a.posePair?.world || a.matrices;batch.depth=m?m[12]*this.viewForward[0]+m[13]*this.viewForward[1]+m[14]*this.viewForward[2]:0;}
		transparent.sort((a,b)=>b.depth-a.depth);
		return [opaque,extra,transparent];
	}
	drawActors(actors, program, view, filter, skyPass=false) {
		const g = this.gl, diag = this.isDiagnostic(program), lit = !this.shadowPass && !diag;
		this.common(program, view); this.eyeBound = true; g.vertexAttrib3f(5,-1,-1,-1);
		g.activeTexture(g.TEXTURE0 + 5); g.bindTexture(g.TEXTURE_2D, this.boneTexture); g.uniform1i(this.u(program, 'boneTex'), 5);
		const offsets = this.drawOffsets ||= new Int32Array(64), location = this.u(program,'boneOffsets[0]'); let previous, vao;
		const same = (a,b) => a === b || a && b && a.length === b.length && a.every((v,i)=>v===b[i]);
		const submit = (actor, command, count) => {
			const {material,mesh} = command, group = mesh.group;
			if (previous !== actor) {
				previous = actor; this.actorSky = !!actor.sky; this.actorSprite=actor.sprite;this.actorTint=actor.tint;this.actorRenderMode=actor.renderMode;
				g.uniform1f(this.u(program, 'cut'), actor.item && !actor.sky ? this.cut : 1e9);
				this.entityAlpha = actor.alpha ?? 1; this.uv(program, 'entityAlpha', this.entityAlpha);
				if (!this.shadowPass) this.uv(program, 'rim', program === this.hullProgram ? actor.outline : actor.rim || [1,1,1,0]);
				if (lit) {
				this.uv(program, 'character', actor.item ? 0 : 1); this.uv(program, 'ownedItem', actor.ownedItem ? 1 : 0);
				const cell = actor.light ||= this.actorLighting(actor), entry = cell.lighting; this.actorCube = cell.cube;
				if (entry !== this.boundLighting) { this.boundLighting = entry;
				g.uniform1f(this.u(program,'ambientOn'),entry?.cube ? 1 : 0); if (entry?.cube) g.uniform3fv(this.u(program,'ambientCube[0]'),entry.cube);
				g.uniform1i(this.u(program,'localCount'),entry?.count || 0); } if (entry?.count && this.boundLights !== entry) { this.boundLights = entry; g.uniform4fv(this.u(program,'localPos[0]'),entry.pos); g.uniform4fv(this.u(program,'localColor[0]'),entry.color); g.uniform4fv(this.u(program,'localDir[0]'),entry.dir); g.uniform4fv(this.u(program,'localAtten[0]'),entry.atten); }
				}
			}
			if (!diag) this.bindMaterial(program, material);
			if (lit) { const eye = group.eyeball >= 0 && material?.iris ? this.eyeball(actor, this.models[actor.path], group.eyeball) : null; if (eye || this.eyeBound) { this.eyeBound = !!eye; g.uniform1f(this.u(program, 'eyeOn'), eye ? 1 : 0); if (eye) { g.uniform3fv(this.u(program, 'eyeOrg'), eye.org); g.uniform3fv(this.u(program, 'eyeRight'), eye.right); g.uniform3fv(this.u(program, 'eyeUp'), eye.up); g.uniform3fv(this.u(program, 'eyeFwd'), eye.forward); } } }
			if (vao !== mesh.vao) g.bindVertexArray(vao = mesh.vao);
			if (count === 1) { g.uniform1i(location,actor.boneOffset); g.drawElements(g.TRIANGLES,mesh.count,mesh.type,0); }
			else { g.uniform1iv(location,offsets,0,count); g.drawElementsInstanced(g.TRIANGLES,mesh.count,mesh.type,0,count); }
		};
		if (diag) {
			for (const actor of actors) if (!filter || filter(actor)) for (const command of actor.commands) if (!command.blended && !(command.material?.alphaByTeam?.[this.viewTeam] <= 0)) submit(actor,command,1);
		} else for (const list of this.drawBatches) for (const batch of (list===this.actorPlan?.opaque ? (skyPass?this.actorPlan.sky:this.actorPlan.main) : list)) {
			let cmd = batch.command, first = null, n = 0;
			for (const member of batch.members) {
				const actor=member.actor;if(!actor)continue;
				if (filter && !filter(actor) || this.shadowPass && (actor.sky || this.models[actor.path].sprite)) continue;
				if(!cmd){cmd=actor.commands.byMesh[batch.mesh];if(!cmd)continue;batch.command=cmd;}
				if(cmd.material?.alphaByTeam?.[this.viewTeam]<=0 || this.shadowPass && cmd.blended)break;
				if (lit) actor.light ||= this.actorLighting(actor);
				if (n && (n === offsets.length || actor.item !== first.item || actor.sprite || first.sprite || lit && (actor.light !== first.light || actor.ownedItem !== first.ownedItem || actor.renderMode !== first.renderMode || actor.alpha !== first.alpha || cmd.mesh.group.eyeball >= 0 && cmd.material?.iris || !same(actor.tint,first.tint) || !same(actor.rim,first.rim)))) { submit(first,cmd,n); n = 0; }
				if (!n) first = actor; offsets[n++] = actor.boneOffset;
			}
			if (n) submit(first,cmd,n);
		}
		g.bindVertexArray(null); g.depthMask(true); g.disable(g.BLEND);
	}

	// ---- Trails and overlays ------------------------------------------------------
	drawViewModel(vm,frame) {
		const g=this.gl,p=this.viewModelProgram,clip=vm.clip,view=vm.view;
		this.common(p,view);g.activeTexture(g.TEXTURE5);
		if(!clip.texture){
			clip.texture=g.createTexture();this.textures.push(clip.texture);g.bindTexture(g.TEXTURE_2D,clip.texture);
			g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MIN_FILTER,g.NEAREST);g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MAG_FILTER,g.NEAREST);
			g.texImage2D(g.TEXTURE_2D,0,g.RGBA32F,clip.count*4,clip.frames,0,g.RGBA,g.FLOAT,clip.palette);delete clip.palette;
		}else g.bindTexture(g.TEXTURE_2D,clip.texture);
		g.uniform1i(this.u(p,'clipTex'),5);g.uniform1f(this.u(p,'phase'),vm.frame);
		g.uniformMatrix4fv(this.u(p,'root'),false,vm.root);
		const lighting=ReplayRenderer.modelLighting(this.map,frame.eye,true);
		g.uniform1f(this.u(p,'ambientOn'),lighting?.cube?1:0);if(lighting?.cube)g.uniform3fv(this.u(p,'ambientCube[0]'),lighting.cube);
		this.entityAlpha=1;this.actorSky=false;this.actorTint=null;this.actorSprite=null;this.actorRenderMode=0;this.actorCube=this.map.cubemapDefault;
		this.uv(p,'entityAlpha',1);this.uv(p,'ownedItem',1);this.uv(p,'character',0);this.uv(p,'rim',[0,0,0,0]);
		g.enable(g.DEPTH_TEST);g.depthRange(0,.01);
		for(const model of [vm.weapon,vm.arms])if(model){
			g.uniform1i(this.u(p,'firstBone'),model===vm.weapon?0:vm.weapon.used.length);
			for(const {mesh,material} of this.modelCommands({path:model.path,body:model===vm.weapon?vm.body:0,skin:model===vm.weapon?vm.skin:0})){
				this.bindMaterial(p,material);g.bindVertexArray(mesh.vao);g.drawElements(g.TRIANGLES,mesh.count,mesh.type,0);
			}
		}
		g.depthRange(0,1);g.depthMask(true);g.disable(g.BLEND);g.bindVertexArray(null);
	}
	// points: Float32Array [t,x,y,z,...], split at recorded gaps and teleports.
	trail(key, points, maxGap, maxStep, width = 5) {
		if (this.trails.has(key)) return this.trails.get(key);
		const count = points.length/4, normals = [], offsets = []; let segments = 0;
		for (let i = 1; i < count; i++) { const a = points.subarray((i-1)*4,i*4), b = points.subarray(i*4,i*4+4), dx = b[1]-a[1], dy = b[2]-a[2], length = Math.hypot(dx,dy); if (b[0]-a[0] <= maxGap && Math.hypot(dx,dy,b[3]-a[3]) <= maxStep) { normals[i] = length > .01 ? [-dy/length,dx/length] : null; if (normals[i]) segments++; } }
		// Repeated stationary samples share the same join at a later change of direction.
		for (let i = 0; i < count; i++) {
			let end = i; while (end+1 < count && normals[end+1] === null) end++;
			const a = normals[i], b = normals[end+1];
			if (a || b) { const n = a && b ? [a[0]+b[0],a[1]+b[1]] : (a || b).slice(), length = Math.hypot(...n), unit = length > .01 ? n.map(v => v/length) : (b || a), next = b || a, scale = width/Math.max(.4,unit[0]*next[0]+unit[1]*next[1]), offset = unit.map(v => v*scale); for (let j = i; j <= end; j++) offsets[j] = offset; }
			i = end;
		}
		const array = new Float32Array(segments * 30), ends = [0,1,1,0,1,0], sides = [-1,-1,1,-1,1,1]; let cursor = 0;
		for (let i = 1; i < count; i++) {
			if (!normals[i]) continue;
			for (let k = 0; k < 6; k++) { const j = i-1+ends[k], side = sides[k], p = points.subarray(j*4,j*4+4), offset = offsets[j]; array[cursor++] = p[1]+offset[0]*side; array[cursor++] = p[2]+offset[1]*side; array[cursor++] = p[3]+1.5; array[cursor++] = p[0]; array[cursor++] = side; }
		}
		const buffer = this.buffer(array), mesh = {count:array.length / 5, buffer, vao:this.vao([[buffer, [[0,3,0],[1,2,12]], 20]])};
		this.trails.set(key, mesh); return mesh;
	}
	clearTrails() {
		const g = this.gl;
		for (const mesh of this.trails.values()) { g.deleteVertexArray(mesh.vao); g.deleteBuffer(mesh.buffer); this.vaos = this.vaos.filter(v => v !== mesh.vao); this.buffers = this.buffers.filter(b => b !== mesh.buffer); }
		this.trails.clear();
	}
	// Static overlay (pos3 + rgba4), e.g. the nav height map.
	staticOverlay(vertices) { const array = vertices instanceof Float32Array ? vertices : new Float32Array(vertices); return {count:array.length / 7, vao:this.vao([[this.buffer(array), [[0,3,0],[1,4,12]], 28]])}; }
	overlay(o, mode) {
		const g = this.gl, p = o.verticesPerParticle ? this.throwableProgram : this.overlayProgram;
		g.useProgram(p); g.uniformMatrix4fv(this.u(p, 'view'), false, o.viewmodelView || this.view); g.uniform1f(this.u(p, 'cut'), o.cut ?? (o.noDepth ? 1e9 : this.cut)); g.uniform1f(this.u(p, 'glowAmount'), o.glow || 0);
		if (o.mesh) { g.bindVertexArray(o.mesh.vao); g.drawArrays(mode, 0, o.mesh.count); g.bindVertexArray(null); return; }
		if(o.verticesPerParticle){g.uniform1i(this.u(p,'kind'),o.kind);g.uniform3fv(this.u(p,'origin'),o.origin);g.uniform3fv(this.u(p,'eye'),this.eye);if(o.forward)g.uniform3fv(this.u(p,'forward'),o.forward);g.uniform1f(this.u(p,'age'),o.age);g.uniform1f(this.u(p,'seed'),o.id);g.bindVertexArray(this.particleVertexVao);g.drawArraysInstanced(mode,0,o.verticesPerParticle,o.count);g.bindVertexArray(null);return;}
		if (!o.vertices.length) return;
		g.bindBuffer(g.ARRAY_BUFFER, this.overlayBuffer); g.bufferData(g.ARRAY_BUFFER, o.vertices instanceof Float32Array ? o.vertices : new Float32Array(o.vertices), g.STREAM_DRAW);
		g.bindVertexArray(this.overlayVao); g.drawArrays(mode, 0, o.vertices.length / 7); g.bindVertexArray(null);
	}

	drawEffects(effects,sky=false) {
		const g=this.gl,p=this.effectProgram;g.useProgram(p);g.uniformMatrix4fv(this.u(p,'view'),false,this.view);g.uniform1f(this.u(p,'cut'),sky?1e9:this.cut);g.uniform1i(this.u(p,'baseTex'),0);g.activeTexture(g.TEXTURE0);g.disable(g.CULL_FACE);g.enable(g.BLEND);g.depthMask(false);
		let softPass=false;g.uniform1i(this.u(p,'sceneDepth'),1);g.activeTexture(g.TEXTURE1);g.bindTexture(g.TEXTURE_2D,this.white);g.activeTexture(g.TEXTURE0);
		const dir=this.viewForward,m=this.view,z=dir[0]*m[2]+dir[1]*m[6]+dir[2]*m[10],w=dir[0]*m[3]+dir[1]*m[7]+dir[2]*m[11];
		g.uniform2f(this.u(p,'depthProjection'),z-w,w);
		for(const effect of effects){
			if(!!effect.sky!==sky||effect.material?.visible===false||!(effect.particleVao||effect.vertices?.length))continue;
			const material=effect.material,v=material.values,card=material.shader==='spritecard',additive=effect.additive||v.$additive==='1',addSelf=card?ReplayRenderer.num(v.$addself):0,mod2x=card&&ReplayRenderer.num(v.$mod2x)!==0,frames=card&&(effect.particleVao?Number(v.$blendframes)>0:effect.frameVertices);
			const fade=card&&ReplayRenderer.num(v.$depthblend)>0?ReplayRenderer.num(v.$depthblendscale ?? 50)*(sky?this.skyScale:1):0;
			if(softPass!==(fade>0)){
				softPass=fade>0;g.activeTexture(g.TEXTURE1);g.bindTexture(g.TEXTURE_2D,softPass?this.scene.depth:this.white);g.activeTexture(g.TEXTURE0);
				g.bindFramebuffer(g.FRAMEBUFFER,softPass?this.softParticleFramebuffer:this.scene.framebuffer);
			}
			g.uniform1f(this.u(p,'depthBlendScale'),fade);
			if(mod2x)g.blendFuncSeparate(g.DST_COLOR,g.SRC_COLOR,g.ZERO,g.ONE);
			else if(addSelf)g.blendFuncSeparate(g.ONE,g.ONE_MINUS_SRC_ALPHA,g.ONE,g.ONE_MINUS_SRC_ALPHA);
			else g.blendFuncSeparate(g.SRC_ALPHA,additive?g.ONE:g.ONE_MINUS_SRC_ALPHA,additive?g.ZERO:g.ONE,additive?g.ONE:g.ONE_MINUS_SRC_ALPHA);
			g.uniform1i(this.u(p,'spriteCard'),card?1:0);g.uniform1i(this.u(p,'blendFrames'),frames?1:0);g.uniform1i(this.u(p,'mod2x'),mod2x?1:0);
			g.uniform1f(this.u(p,'overbright'),ReplayRenderer.num(v.$overbrightfactor ?? 1));g.uniform1f(this.u(p,'addSelf'),addSelf);g.uniform1f(this.u(p,'additive'),additive?1:0);
			g.bindTexture(g.TEXTURE_2D,material.texture?this.texture(material.texture,effect.frame || 0):this.white);g.bindVertexArray(effect.particleVao || (frames?this.effectFrameVao:this.effectVao));
			g.uniform1i(this.u(p,'particle'),effect.particleVao?1:0);
			if(effect.particleVao){g.uniform4fv(this.u(p,'sizes'),effect.sizes);g.uniform3fv(this.u(p,'eye'),effect.eye);g.uniform4f(this.u(p,'space'),...(sky?this.map.sky.origin:[0,0,0]),sky?this.skyScale:1);g.uniform1f(this.u(p,'velocityAngle'),effect.velocityAngle);g.uniform1f(this.u(p,'visibility'),effect.visibility);g.uniform2fv(this.u(p,'trailLengths'),effect.trail || [0,-1]);}
			else{if(frames){g.bindBuffer(g.ARRAY_BUFFER,this.effectFrameBuffer);g.bufferData(g.ARRAY_BUFFER,frames,g.STREAM_DRAW);}
			g.bindBuffer(g.ARRAY_BUFFER,this.effectBuffer);g.bufferData(g.ARRAY_BUFFER,effect.vertices,g.STREAM_DRAW);}
			if(effect.particleVao){g.uniform2f(this.u(p,'crop'),effect.cropX,effect.cropY);g.drawArraysInstanced(g.TRIANGLES,0,6,effect.instanceCount);}
			else g.drawArrays(g.TRIANGLES,0,effect.vertices.length/9);
		}
		if(softPass){g.activeTexture(g.TEXTURE1);g.bindTexture(g.TEXTURE_2D,this.white);g.activeTexture(g.TEXTURE0);g.bindFramebuffer(g.FRAMEBUFFER,this.scene.framebuffer);}
		g.bindVertexArray(null);g.depthMask(true);g.disable(g.BLEND);
	}

	// ---- Targets ------------------------------------------------------------------
	target(width, height, formats, depth) {
		const g = this.gl, framebuffer = g.createFramebuffer(); g.bindFramebuffer(g.FRAMEBUFFER, framebuffer); const textures = [];
		formats.forEach((format, i) => {
			const t = g.createTexture(); g.bindTexture(g.TEXTURE_2D, t);
			const [internal, type] = format === 'float' ? [g.RGBA32F,g.FLOAT] : format === 'hdr' ? (this.hdr ? [g.RGBA16F, g.HALF_FLOAT] : [g.RGBA8, g.UNSIGNED_BYTE]) : [g.RGBA8, g.UNSIGNED_BYTE];
			g.texImage2D(g.TEXTURE_2D, 0, internal, width, height, 0, g.RGBA, type, null);
			for (const [p, v] of [[g.TEXTURE_MIN_FILTER, format==='float'?g.NEAREST:g.LINEAR], [g.TEXTURE_MAG_FILTER, format==='float'?g.NEAREST:g.LINEAR], [g.TEXTURE_WRAP_S, g.CLAMP_TO_EDGE], [g.TEXTURE_WRAP_T, g.CLAMP_TO_EDGE]]) g.texParameteri(g.TEXTURE_2D, p, v);
			g.framebufferTexture2D(g.FRAMEBUFFER, g.COLOR_ATTACHMENT0 + i, g.TEXTURE_2D, t, 0); textures.push(t);
		});
		let depthTexture = null;
		if (depth) {
			depthTexture = g.createTexture(); g.bindTexture(g.TEXTURE_2D, depthTexture); g.texImage2D(g.TEXTURE_2D, 0, g.DEPTH_COMPONENT24, width, height, 0, g.DEPTH_COMPONENT, g.UNSIGNED_INT, null);
			for (const [p, v] of [[g.TEXTURE_MIN_FILTER, g.NEAREST], [g.TEXTURE_MAG_FILTER, g.NEAREST], [g.TEXTURE_WRAP_S, g.CLAMP_TO_EDGE], [g.TEXTURE_WRAP_T, g.CLAMP_TO_EDGE]]) g.texParameteri(g.TEXTURE_2D, p, v);
			g.framebufferTexture2D(g.FRAMEBUFFER, g.DEPTH_ATTACHMENT, g.TEXTURE_2D, depthTexture, 0);
		}
		g.drawBuffers(formats.length ? textures.map((_, i) => g.COLOR_ATTACHMENT0 + i) : [g.NONE]); if (!formats.length) g.readBuffer(g.NONE);
		if (g.checkFramebufferStatus(g.FRAMEBUFFER) !== g.FRAMEBUFFER_COMPLETE) throw Error('浏览器无法建立回放渲染目标');
		const result = {framebuffer, textures, depth:depthTexture, width, height}; this.targets.push(result); return result;
	}
	resize(w, h) {
		if (this.width === w && this.height === h) return; const g = this.gl; this.destroyTargets(); this.width = w; this.height = h;
		this.scene = this.target(w, h, ['hdr', 'hdr', 'ldr'], true);
		// Same colour targets, no depth attachment: soft particles can read scene depth without copying it.
		this.softParticleFramebuffer=g.createFramebuffer();g.bindFramebuffer(g.FRAMEBUFFER,this.softParticleFramebuffer);
		for(let i=0;i<2;i++)g.framebufferTexture2D(g.FRAMEBUFFER,g.COLOR_ATTACHMENT0+i,g.TEXTURE_2D,this.scene.textures[i],0);
		g.drawBuffers([g.COLOR_ATTACHMENT0,g.COLOR_ATTACHMENT1]);this.targets.push({framebuffer:this.softParticleFramebuffer,textures:[]});
		this.diagnostics = this.target(w, h, ['ldr'], false);
		g.framebufferTexture2D(g.FRAMEBUFFER, g.DEPTH_ATTACHMENT, g.TEXTURE_2D, this.scene.depth, 0);
		this.ao = this.target(Math.max(1, w >> 1), Math.max(1, h >> 1), ['ldr'], false);
		this.composite = this.target(w, h, ['hdr'], false);
		this.post = this.target(w, h, ['ldr'], false);
		this.histogram = []; let histogramWidth = w, histogramHeight = h;
		do { histogramWidth = Math.max(1,Math.ceil(histogramWidth/4)); histogramHeight = Math.max(1,Math.ceil(histogramHeight/4)); this.histogram.push(this.target(histogramWidth,histogramHeight,['float','float','float','float'],false)); } while (histogramWidth>1 || histogramHeight>1);
		this.exposureTargets = [this.target(11,1,['float'],false),this.target(11,1,['float'],false)]; this.exposureFrames = 0; this.exposureClock = null;
		this.shadow = this.target(this.shadowSize, this.shadowSize, [], true); this.staticShadow = this.target(this.shadowSize, this.shadowSize, [], true);
		this.flashlightShadow = this.target(2048, 2048, [], true);
		for (const t of [this.shadow, this.staticShadow, this.flashlightShadow]) { g.bindTexture(g.TEXTURE_2D, t.depth); g.texParameteri(g.TEXTURE_2D, g.TEXTURE_COMPARE_MODE, g.COMPARE_REF_TO_TEXTURE); g.texParameteri(g.TEXTURE_2D, g.TEXTURE_COMPARE_FUNC, g.LEQUAL); g.texParameteri(g.TEXTURE_2D, g.TEXTURE_MIN_FILTER, g.LINEAR); g.texParameteri(g.TEXTURE_2D, g.TEXTURE_MAG_FILTER, g.LINEAR); }
		this.shadowKey = null;
		this.bloomLevels = Array.from({length:4}, (_, i) => { const width = Math.max(1, w >> (i+1)), height = Math.max(1, h >> (i+1)); return {down:this.target(width, height, ['hdr'], false), horizontal:this.target(width, height, ['hdr'], false), blur:this.target(width, height, ['hdr'], false)}; });
	}
	destroyTargets() { const g = this.gl; for (const t of this.targets) { g.deleteFramebuffer(t.framebuffer); if (t.depth) g.deleteTexture(t.depth); for (const x of t.textures) g.deleteTexture(x); } this.targets = []; }

	// ---- Frame ----------------------------------------------------------------------
	drawFlashlightDepth(lights, actors) {
		this.flashlightCount = Math.min(lights.length, 4);
		if (!this.flashlightCount) return;
		const g = this.gl, cut = this.cut, tile = this.flashlightShadow.width / 2;
		this.shadowPass = true; this.cut = 1e9;
		g.bindFramebuffer(g.FRAMEBUFFER, this.flashlightShadow.framebuffer); g.clear(g.DEPTH_BUFFER_BIT);
		g.enable(g.POLYGON_OFFSET_FILL); g.polygonOffset(1.5, 2.0);
		for (let i = 0; i < this.flashlightCount; i++) {
			const light = lights[i], excluded = new Set([light.owner, ...(light.inventory || []).map(item => item.id)]);
			this.flashlightViews.set(light.view, i * 16); this.flashlightOrigins.set(light.origin, i * 3);
			g.viewport((i & 1) * tile, (i >> 1) * tile, tile, tile);
			this.drawWorld(light.planes, false, false, undefined, light.view);
			this.drawActors(actors, this.shadowSkin, light.view, actor => !excluded.has(actor.id));
		}
		g.disable(g.POLYGON_OFFSET_FILL); this.cut = cut; this.shadowPass = false;
	}
	drawFlashlightBeams(lights) {
		const material = this.map.flashlightGlow;
		if (!this.flashlightCount || !material?.texture) return;
		const g = this.gl, p = this.flashlightBeam;
		g.useProgram(p); g.bindVertexArray(this.empty); g.drawBuffers([g.COLOR_ATTACHMENT0]);
		this.bind(p, [['sprite',this.texture(material.texture)],['depthAtlas',this.flashlightShadow.depth]]);
		g.uniformMatrix4fv(this.u(p, 'view'), false, this.view); g.uniform3fv(this.u(p, 'eye'), this.eye);
		g.uniform1f(this.u(p, 'cut'), this.cut); g.uniform1f(this.u(p, 'overbright'), ReplayRenderer.num(material.values.$overbrightfactor));
		g.depthMask(false); g.enable(g.BLEND); g.blendFuncSeparate(g.ONE,g.ONE,g.ZERO,g.ONE);
		for (let i = 0; i < this.flashlightCount; i++) {
			const light = lights[i];
			g.uniformMatrix4fv(this.u(p, 'projector'), false, light.view); g.uniform3fv(this.u(p, 'origin'), light.origin);
			g.uniform2f(this.u(p, 'tile'), i & 1, i >> 1); g.drawArraysInstanced(g.TRIANGLES, 0, 6, 18);
		}
		g.bindVertexArray(null); g.disable(g.BLEND); g.depthMask(true);
	}
	presentExposure() {
		const frame=this.exposureFrame; if (!frame) return;
		const g=this.gl, s=frame.settings; g.disable(g.DEPTH_TEST); g.disable(g.BLEND); g.bindVertexArray(this.empty);
		this.updateExposure(frame);
		const tone=this.tonemapProgram; g.bindFramebuffer(g.FRAMEBUFFER,s.fxaa?this.post.framebuffer:null); g.viewport(0,0,this.width,this.height); g.useProgram(tone);
		this.bind(tone,[['source',this.composite.textures[0]],['exposureTex',this.exposureTargets[0].textures[0]],['overlayTex',this.diagnostics.textures[0]],['depthTex',this.scene.depth],['gbufTex',this.scene.textures[2]],...this.bloomLevels.map((level,i)=>['bloom'+i,level.blur.textures[0]]),['coverageTex',this.coverageTexture]]); g.uniform2fv(this.u(tone,'effects'),[s.bloom ? .55*this.bloomScale : 0,.55]);g.uniform1f(this.u(tone,'toonGrade'),s.realism ? 0 : 1);g.uniform1i(this.u(tone,'coverageRows'),this.coverageRows);
		g.uniformMatrix4fv(this.u(tone,'inverseView'),false,SourceModel.inverse(frame.view));g.uniform1i(this.u(tone,'ringCount'),frame.groundRings.length);for(let i=0;i<frame.groundRings.length;i++){const ring=frame.groundRings[i];g.uniform4fv(this.u(tone,'ringSphere['+i+']'),ring.sphere);g.uniform3fv(this.u(tone,'ringTone['+i+']'),ring.color);}g.drawArrays(g.TRIANGLES,0,3);
		if (s.fxaa) { const f = this.fxaaProgram; g.bindFramebuffer(g.FRAMEBUFFER, null); g.useProgram(f); this.bind(f, [['source', this.post.textures[0]]]); g.uniform2fv(this.u(f, 'texel'), [1/this.width, 1/this.height]); g.drawArrays(g.TRIANGLES, 0, 3); }
		g.bindVertexArray(null); g.enable(g.DEPTH_TEST);
	}
	updateExposure(frame) {
		const g = this.gl, controllers = (frame.environment || []).filter(entity=>entity.classname?.startsWith('env_tonemap_controller'));
		let controller = null;
		if (frame.tonemapController !== undefined) { if (frame.tonemapController !== null) controller = controllers.find(entity=>entity.id===frame.tonemapController); }
		else for (const entity of controllers) if (entity.classname==='env_tonemap_controller' && (!controller || entity.spawnflags&1)) controller=entity;
		this.bloomScale = controller?.m_bUseCustomBloomScale ? controller.m_flCustomBloomScale : 1;
		const min = controller?.m_bUseCustomAutoExposureMin && controller.m_flCustomAutoExposureMin>0 ? controller.m_flCustomAutoExposureMin : .1;
		const max = Math.max(min,controller?.m_bUseCustomAutoExposureMax && controller.m_flCustomAutoExposureMax>0 ? controller.m_flCustomAutoExposureMax : 8);
		const previous = this.exposureTargets[0], destination = this.exposureTargets[1];
		for (let i=0;i<this.histogram.length;i++) {
			const target=this.histogram[i], program=i ? this.histogramReduceProgram : this.histogramProgram;
			g.bindFramebuffer(g.FRAMEBUFFER,target.framebuffer); g.viewport(0,0,target.width,target.height); g.useProgram(program);
			if (i) this.bind(program,this.histogram[i-1].textures.map((texture,k)=>['source'+k,texture]));
			else { this.bind(program,[['source',this.composite.textures[0]],['exposureTex',previous.textures[0]]]); g.uniform1i(this.u(program,'initial'),this.exposureFrames===0?1:0); }
			g.drawArrays(g.TRIANGLES,0,3);
		}
		const program=this.exposureProgram, now=performance.now(); g.bindFramebuffer(g.FRAMEBUFFER,destination.framebuffer); g.viewport(0,0,11,1); g.useProgram(program);
		this.bind(program,[...this.histogram.at(-1).textures.map((texture,k)=>['source'+k,texture]),['previous',previous.textures[0]]]);
		g.uniform3fv(this.u(program,'parameters'),[(controller?.m_flTonemapPercentTarget ?? 45)/100,(controller?.m_flTonemapPercentBrightPixels ?? 1)/100,(controller?.m_flTonemapMinAvgLum ?? 3)/100]);
		g.uniform2fv(this.u(program,'limits'),[min,max]); g.uniform1f(this.u(program,'elapsed'),this.exposureClock===null?0:(now-this.exposureClock)/1000); g.uniform1i(this.u(program,'history'),this.exposureFrames);
		g.drawArrays(g.TRIANGLES,0,3); this.exposureTargets=[destination,previous]; this.exposureFrames=Math.min(10,this.exposureFrames+1); this.exposureClock=now;
	}
	fog(frame, selected) {
		if (selected === undefined) {
			const environment = frame.environment || [], controllers = environment.filter(entity=>entity.classname==='env_fog_controller');
			selected = null;
			if (frame.fogController !== undefined) {
				if (frame.fogController === null) return null;
				selected = controllers.find(controller=>controller.id===frame.fogController);
			} else {
				for (const controller of controllers) if (!selected || controller.spawnflags & 1) selected = controller;
				for (const volume of environment) {
					if (volume.classname !== 'fog_volume' || volume.fog.disabled || !volume.hull) continue;
					const hull = volume.hull, delta = (frame.visibilityOrigin || frame.eye).map((v,k)=>v-volume.origin[k]); let point = delta;
					if (!(hull.flags & 64) && hull.solid !== 2 && hull.solid !== 0) {
						const rotation = ReplayRenderer.transform([0,0,0],volume.angles);
						point = [0,1,2].map(axis=>delta.reduce((sum,v,k)=>sum+v*rotation[axis*4+k],0));
					}
					// CFogVolume tests a radius-one sphere against its local collision OBB.
					if (point.reduce((sum,v,k)=>sum+Math.max(hull.mins[k]-v,0,v-hull.maxs[k])**2,0) >= 1) continue;
					if (volume.fog.controller !== null) selected = controllers.find(controller=>controller.id===volume.fog.controller) || selected;
					break;
				}
			}
		}
		if (!selected?.['m_fog.enable']) return null;
		const end = selected['m_fog.lerptime'], duration = selected['m_fog.duration'], blend = end != null && duration > 0 && end >= frame.time ? Math.max(0,Math.min(1,1-(end-frame.time)/duration)) : 0;
		const value = key => { const from = selected['m_fog.'+key], to = selected['m_fog.'+key+'LerpTo']; return blend && to != null ? from+(to-from)*blend : from; };
		const color = key => { const from = selected['m_fog.'+key], to = selected['m_fog.'+key+'LerpTo']; return [0,8,16].map(shift=>{const channel=from>>>shift&255;return blend && to != null ? channel+((to>>>shift&255)-channel)*blend : channel;}); };
		const primary = color('colorPrimary'), secondary = color('colorSecondary'), forward = ReplayRenderer.normalize(frame.focus.map((v,k)=>v-frame.eye[k])), direction = ReplayRenderer.normalize(selected.direction || [0,0,0]), factor = selected['m_fog.blend'] ? .5+.5*forward.reduce((sum,v,k)=>sum+v*direction[k],0) : 1;
		return {color:primary.map((v,k)=>((v*factor+secondary[k]*(1-factor))/255)**2.2*(selected['m_fog.HDRColorScale'] ?? 1)), start:value('start'), end:value('end'), density:value('maxdensity')};
	}
	// frame: {width,height,view,eye,focus,cut,ortho,actors,xray,trails,overlays,settings}
	render(frame) {
		const g = this.gl, s = frame.settings; this.settings = s; this.resize(frame.width, frame.height);
		this.viewTeam = frame.viewTeam ?? 0;
		this.coverageRows=frame.coverage.length/8;g.bindTexture(g.TEXTURE_2D,this.coverageTexture);g.texImage2D(g.TEXTURE_2D,0,g.RGBA32F,2,Math.max(1,this.coverageRows),0,g.RGBA,g.FLOAT,this.coverageRows?frame.coverage:null);
		this.exposureFrame = {environment:frame.environment,tonemapController:frame.tonemapController,settings:s,view:frame.view,groundRings:frame.groundRings};
		this.time = frame.time || 0;
		frame.actors=frame.actors.filter(actor=>actor.renderMode!==10);
		// Billboards and ribbons use one camera-facing matrix rather than a skinned mesh palette.
		for(const actor of frame.actors)if(actor.posePair && this.models[actor.path]?.sprite){actor.matrices=actor.posePair.skinAt(0);actor.posePair=null;}
		const effects=this.particles.prepare(frame.effects || []);for(const actor of frame.actors)if((actor.beam||actor.trail)&&this.models[actor.path]?.sprite){const effect=actor.trail?SourceSprite.trail(this.models[actor.path],actor,frame.eye,this.time):SourceSprite.beam(this.models[actor.path],actor,frame.eye,this.time);if(effect){effect.sky=!!actor.sky;const beam=actor.beam;if(beam?.coordinateScale>0&&beam.coordinateScale!==1&&!(beam.flags&512)){const scroll=this.time*(beam.speed || 0)%1;for(let i=4;i<effect.vertices.length;i+=9)effect.vertices[i]=scroll+(effect.vertices[i]-scroll)/beam.coordinateScale;}effects.push(effect);}}frame.actors=frame.actors.filter(actor=>!actor.beam&&!actor.trail);
		const hour = frame.timeOfDay, angles = this.environment?.sunAngles || [-55,-128,0], phase = (Number(hour)-6)*Math.PI/12;
		this.mapLighting = hour == null;
		this.sunPosition = hour == null ? (this.environment?.sunDirection || ReplayRenderer.point(ReplayRenderer.transform([0,0,0], [angles[0], angles[1]+180, 0]), [1,0,0], 0)) : ReplayRenderer.normalize([Math.cos(phase), -.35, Math.sin(phase)]);
		this.daylight = Math.max(0, Math.min(1, (this.sunPosition[2]+.08)*4));
		this.sunDir = this.sunPosition.map(v => v * (this.sunPosition[2] >= 0 ? 1 : -1));
		// Night (moon/sky) levels sit just under the maps' baked street lighting (~.005-.03), so lamps
		// still read as the light sources at night instead of being washed out by moonlight.
		this.sunColor = hour == null ? this.environment.sunColor : [1.16,1.02,.86].map((v, i) => v*this.daylight + [.008,.011,.019][i]*(1-this.daylight));
		this.skyColor = hour == null ? this.environment.ambientColor : [.62,.72,.95].map((v, i) => v*this.daylight + [.004,.006,.013][i]*(1-this.daylight));
		if (hour == null) this.daylight = Math.min(1,Math.max(...this.sunColor,...this.skyColor));
		this.view = frame.view; this.eye = frame.eye; this.cut = frame.cut; const stats = {world:0, actors:frame.actors.length};
		this.viewForward = ReplayRenderer.normalize(frame.focus.map((v,k)=>v-frame.eye[k])); // Fog is measured from the followed point, not from the orbit camera: the game's fog
		// distances are from the player's eye, and an overview camera sits far behind it. The fog
		// setting stretches (half) or removes it for the world and the 3D skybox alike.
		this.fogScale = s.fog === 'off' ? 0 : s.fog === 'half' ? 2 : 1; this.fogOffset = frame.ortho ? 0 : Math.max(0, frame.focus.reduce((sum,v,k)=>sum+(v-frame.eye[k])*this.viewForward[k],0));
		const skyFog = this.map.sky && this.fogScale ? this.fog(frame,this.map.sky.fog) : null; this.skyFog = skyFog && {...skyFog, start:skyFog.start*this.fogScale+this.fogOffset, end:skyFog.end*this.fogScale+this.fogOffset};
		for (const actor of frame.actors) { this.meshFor(actor.path); const model=this.models[actor.path];if(model?.sprite)actor.matrices=SourceSprite.matrix(model,actor,frame.eye,frame.view); }
		this.actorPlan=frame.draws;this.drawBatches = this.frameCommands(frame.actors, frame.draws);
		this.uploadBones(frame.actors);
		g.enable(g.DEPTH_TEST); g.depthFunc(g.LESS); g.disable(g.CULL_FACE); g.disable(g.BLEND); g.depthMask(true);
		// Shadows: the world part is re-rendered only when the light frustum moves.
		const dist = Math.hypot(...frame.eye.map((v, k) => v - frame.focus[k]));
		const radius = Math.max(4096, Math.min(12000, Math.ceil(dist * 1.6 / 1024) * 1024)); this.shadowRadius = radius;
		const snap = radius / 64, center = frame.focus.map((v, k) => k < 2 ? Math.round(v / snap) * snap : Math.round(v / 256) * 256);
		const key = center.join(',') + '|' + radius + '|' + this.sunDir.join(',') + '|' + this.viewTeam;
		if (s.shadows) {
			if (key !== this.shadowKey) {
				const z = this.sunDir, x = ReplayRenderer.normalize([-z[1]*1 + 0, z[0], 0].map((v, i) => i === 2 ? 0 : v)), y = [z[1]*x[2]-z[2]*x[1], z[2]*x[0]-z[0]*x[2], z[0]*x[1]-z[1]*x[0]];
				const eyeL = center.map((v, k) => v + z[k] * radius * 2.5), dot = (a, b) => a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
				const camera = new Float32Array([x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-dot(x,eyeL),-dot(y,eyeL),-dot(z,eyeL),1]);
				const far = radius * 6, projection = new Float32Array([1/radius,0,0,0,0,1/radius,0,0,0,0,-2/(far-1),0,0,0,-(far+1)/(far-1),1]);
				this.lightView = SourceModel.multiply(projection, camera); this.lightPlanes = ReplayRenderer.planes(this.lightView);
				this.shadowPass = true; g.bindFramebuffer(g.FRAMEBUFFER, this.staticShadow.framebuffer); g.viewport(0, 0, this.shadowSize, this.shadowSize); g.clear(g.DEPTH_BUFFER_BIT);
				g.enable(g.POLYGON_OFFSET_FILL); g.polygonOffset(1.5, 2.0); // Roofs above the view slice still block the sun: the cut is for the camera only.
				const cut = this.cut; this.cut = 1e9; stats.shadowWorld = this.drawWorld(this.lightPlanes, false); this.cut = cut; g.disable(g.POLYGON_OFFSET_FILL);
				this.shadowKey = key; stats.shadowRebuilt = true;
			}
			g.bindFramebuffer(g.READ_FRAMEBUFFER, this.staticShadow.framebuffer); g.bindFramebuffer(g.DRAW_FRAMEBUFFER, this.shadow.framebuffer);
			g.blitFramebuffer(0, 0, this.shadowSize, this.shadowSize, 0, 0, this.shadowSize, this.shadowSize, g.DEPTH_BUFFER_BIT, g.NEAREST);
			g.bindFramebuffer(g.FRAMEBUFFER, this.shadow.framebuffer); g.viewport(0, 0, this.shadowSize, this.shadowSize);
			this.shadowPass = true; g.enable(g.POLYGON_OFFSET_FILL); g.polygonOffset(1.5, 2.0); this.drawActors(frame.actors, this.shadowSkin, this.lightView); g.disable(g.POLYGON_OFFSET_FILL);
		} else if (!this.lightView) this.lightView = new Float32Array(16);
		this.shadowPass = false;
		this.drawFlashlightDepth(frame.flashlights, frame.actors);
		// Diagnostic colors are composited after tone mapping and never enter the luminance histogram.
		g.bindFramebuffer(g.FRAMEBUFFER,this.diagnostics.framebuffer);g.drawBuffers([g.COLOR_ATTACHMENT0]);g.clearBufferfv(g.COLOR,0,new Float32Array([0,0,0,0]));
		// Main pass.
		g.bindFramebuffer(g.FRAMEBUFFER, this.scene.framebuffer); g.viewport(0, 0, this.width, this.height);
		g.drawBuffers([g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1, g.COLOR_ATTACHMENT2]);
		g.clearBufferfv(g.COLOR, 0, new Float32Array([0,0,0,0])); g.clearBufferfv(g.COLOR, 1, new Float32Array([0,0,0,1])); g.clearBufferfv(g.COLOR, 2, new Float32Array([0,0,0,0])); g.clear(g.DEPTH_BUFFER_BIT);
		const planes = ReplayRenderer.planes(frame.view);
		// Source's 3D skybox is a background scene. Its enlarged proxy buildings must
		// not compete with playable geometry for depth, even when their planes overlap.
		const skyView = (frame.skyPerspective || frame.view).slice(), skyNear = 2*this.skyScale, skyFar = 32768*Math.sqrt(3)*this.skyScale;
		if (frame.ortho && !frame.skyPerspective) {
			const back = ReplayRenderer.normalize(frame.eye.map((v,k)=>v-frame.focus[k])), scale = -2/(skyFar-skyNear);
			for (let k=0;k<3;k++) skyView[k*4+2] = back[k]*scale;
			skyView[14] = -back.reduce((sum,v,k)=>sum+v*frame.eye[k],0)*scale-(skyFar+skyNear)/(skyFar-skyNear);
		} else {
			for (let k=0;k<4;k++) skyView[k*4+2] = skyView[k*4+3]*(skyFar+skyNear)/(skyFar-skyNear);
			skyView[14] -= 2*skyFar*skyNear/(skyFar-skyNear);
		}
		this.view = skyView; const skyPlanes = ReplayRenderer.planes(skyView);
		stats.world = this.drawWorld(skyPlanes, false, true);
		this.drawActors(frame.actors, this.skinProgram, this.view, actor => actor.sky,true);
		this.drawWorld(skyPlanes, true, true);
		g.drawBuffers([g.COLOR_ATTACHMENT0,g.COLOR_ATTACHMENT1]);this.drawEffects(effects,true);
		g.depthMask(true); g.clear(g.DEPTH_BUFFER_BIT);
		this.view = frame.view;
		g.drawBuffers([g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1, g.COLOR_ATTACHMENT2]);
		stats.world += this.drawWorld(planes, false, false, false);
		g.drawBuffers([g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1, g.COLOR_ATTACHMENT2]);
		this.drawActors(frame.actors, this.skinProgram, this.view, actor => !actor.sky);
		// Share scene depth for diagnostic occlusion while keeping their colors outside HDR. X-ray
		// runs before alpha-tested world (chain-link fences, grates, foliage): someone behind a fence
		// is visible through it and should not be drawn as hidden.
		g.bindFramebuffer(g.FRAMEBUFFER,this.diagnostics.framebuffer);g.drawBuffers([g.COLOR_ATTACHMENT0]);
		if(s.xray&&frame.xray.length){
			g.useProgram(this.xrayProgram);g.activeTexture(g.TEXTURE0+6);g.bindTexture(g.TEXTURE_2D,this.scene.textures[2]);g.uniform1i(this.u(this.xrayProgram,'actorMask'),6);g.depthFunc(g.GREATER);g.depthMask(false);g.enable(g.BLEND);g.blendFuncSeparate(g.SRC_ALPHA,g.ONE_MINUS_SRC_ALPHA,g.ONE,g.ONE_MINUS_SRC_ALPHA);
			this.drawActors(frame.actors,this.xrayProgram,this.view,actor=>actor.xray);g.depthFunc(g.LESS);
		}
		if(frame.actors.some(actor=>actor.outline)){
			g.useProgram(this.hullProgram);g.uniform1f(this.u(this.hullProgram,'inflate'),1.7);g.disable(g.BLEND);g.depthFunc(g.LESS);g.depthMask(false);g.enable(g.CULL_FACE);g.frontFace(g.CCW);g.cullFace(g.FRONT);
			this.drawActors(frame.actors,this.hullProgram,this.view,actor=>actor.outline);g.cullFace(g.BACK);g.disable(g.CULL_FACE);
		}
		g.depthMask(true); g.disable(g.BLEND);
		g.bindFramebuffer(g.FRAMEBUFFER, this.scene.framebuffer); g.drawBuffers([g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1, g.COLOR_ATTACHMENT2]);
		stats.world += this.drawWorld(planes, false, false, true);
		g.drawBuffers([g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1]);
		this.drawWorld(planes, true);
		g.drawBuffers([g.COLOR_ATTACHMENT0, g.COLOR_ATTACHMENT1]);
		this.drawEffects(effects);
		this.drawFlashlightBeams(frame.flashlights);
		if(frame.viewmodel){g.drawBuffers([g.COLOR_ATTACHMENT0,g.COLOR_ATTACHMENT1,g.COLOR_ATTACHMENT2]);this.drawViewModel(frame.viewmodel,frame);}
		g.bindFramebuffer(g.FRAMEBUFFER,this.diagnostics.framebuffer);g.drawBuffers([g.COLOR_ATTACHMENT0]);
		g.disable(g.CULL_FACE);g.enable(g.BLEND);g.depthMask(false);
		if (frame.trails.length) {
			const p = this.trailProgram; g.useProgram(p); g.uniformMatrix4fv(this.u(p, 'view'), false, this.view); g.uniform1f(this.u(p, 'cut'), this.cut);
			g.blendFuncSeparate(g.SRC_ALPHA,g.ONE_MINUS_SRC_ALPHA,g.ONE,g.ONE_MINUS_SRC_ALPHA);
			for (const trail of frame.trails) { g.uniform1f(this.u(p, 'now'), trail.now); g.uniform1f(this.u(p, 'span'), trail.span); g.uniform3fv(this.u(p, 'tone'), trail.color); g.uniform1f(this.u(p, 'strength'), trail.strength ?? 1); g.bindVertexArray(trail.mesh.vao); g.drawArrays(g.TRIANGLES, 0, trail.mesh.count); }
			g.bindVertexArray(null);
		}
		for (const o of frame.overlays) { g.blendFuncSeparate(g.SRC_ALPHA,o.additive?g.ONE:g.ONE_MINUS_SRC_ALPHA,o.additive?g.ZERO:g.ONE,o.additive?g.ONE:g.ONE_MINUS_SRC_ALPHA);if (o.noDepth) g.disable(g.DEPTH_TEST); if(o.viewmodelView)g.depthRange(0,.01);this.overlay(o, o.mode === 'lines' ? g.LINES : g.TRIANGLES);if(o.viewmodelView)g.depthRange(0,1);g.enable(g.DEPTH_TEST); }
		g.depthMask(true); g.disable(g.BLEND); g.disable(g.DEPTH_TEST);
		// Post.
		const inverse = SourceModel.inverse(frame.view), pixelScale = this.height * .5 * Math.hypot(frame.view[1], frame.view[5], frame.view[9]);
		g.bindVertexArray(this.empty);
		if (s.ao) {
			g.bindFramebuffer(g.FRAMEBUFFER, this.ao.framebuffer); g.viewport(0, 0, this.ao.width, this.ao.height); const p = this.aoProgram; g.useProgram(p);
			this.bind(p, [['depthTex', this.scene.depth], ['gbufTex', this.scene.textures[2]]]);
			g.uniformMatrix4fv(this.u(p, 'inverseView'), false, inverse); g.uniform3fv(this.u(p, 'eye'), frame.eye); g.uniform2fv(this.u(p, 'screen'), [this.width, this.height]); g.uniform1f(this.u(p, 'pixelScale'), pixelScale);
			g.drawArrays(g.TRIANGLES, 0, 3);
		}
		if (s.bloom) {
			let source = this.scene.textures[1], width = this.width, height = this.height;
			for (let i = 0; i < this.bloomLevels.length; i++) {
				const level = this.bloomLevels[i], down = this.downsampleProgram; g.useProgram(down);
				g.bindFramebuffer(g.FRAMEBUFFER, level.down.framebuffer); g.viewport(0, 0, level.down.width, level.down.height);
				this.bind(down, [['source', source]]); g.uniform2fv(this.u(down, 'stepSize'), [1/width, 1/height]); g.uniform1f(this.u(down, 'prefilter'), i === 0 ? 1 : 0); g.drawArrays(g.TRIANGLES, 0, 3);
				const blur = this.blurProgram; g.useProgram(blur); source = level.down.textures[0]; width = level.down.width; height = level.down.height;
				for (const [target, step] of [[level.horizontal, [1/width, 0]], [level.blur, [0, 1/height]]]) { g.bindFramebuffer(g.FRAMEBUFFER, target.framebuffer); g.viewport(0, 0, width, height); this.bind(blur, [['source', source]]); g.uniform2fv(this.u(blur, 'stepSize'), step); g.drawArrays(g.TRIANGLES, 0, 3); source = target.textures[0]; }
				source = level.down.textures[0];
			}
		}
		const c = this.compositeProgram; g.bindFramebuffer(g.FRAMEBUFFER, this.composite.framebuffer); g.viewport(0, 0, this.width, this.height); g.useProgram(c);
		g.uniform3fv(this.u(c, 'sunPosition'), this.sunPosition); g.uniform1f(this.u(c, 'daylight'), this.daylight);
		const skyMaterials=this.environment.skyMaterials || [];
		this.bind(c, [['colorTex', this.scene.textures[0]], ['depthTex', this.scene.depth], ['gbufTex', this.scene.textures[2]], ['aoTex', this.ao.textures[0]], ...['Right','Left','Back','Front','Up','Down'].map((suffix,i)=>['sky'+suffix,skyMaterials[i]?.texture ? this.texture(skyMaterials[i].texture) : this.black])]);
		g.uniform1fv(this.u(c,'skyEncoding[0]'),[0,1,2,3,4,5].map(i=>skyMaterials[i]?.encoding || 0));g.uniform3fv(this.u(c,'skyTransform[0]'),[0,1,2,3,4,5].flatMap(i=>skyMaterials[i]?.transform || [1,0,0,0,1,0]));g.uniform3fv(this.u(c,'skyTint[0]'),[0,1,2,3,4,5].flatMap(i=>skyMaterials[i]?.color || [1,1,1]));
		g.uniform1f(this.u(c,'mapSky'),frame.timeOfDay == null ? skyMaterials.length===6&&skyMaterials.every(face=>face.texture) ? 1 : -1 : 0); g.uniform3fv(this.u(c,'environmentColor'),this.skyColor);
		const fog = this.fog(frame);
		g.uniform3fv(this.u(c,'fogColor'),fog?.color || [0,0,0]);
		g.uniform3fv(this.u(c,'fogRange'),fog && this.fogScale ? [fog.start*this.fogScale+this.fogOffset,fog.end*this.fogScale+this.fogOffset,fog.density] : [0,1,0]);g.uniform3fv(this.u(c,'viewForward'),ReplayRenderer.normalize(frame.focus.map((v,k)=>v-frame.eye[k])));
		g.uniformMatrix4fv(this.u(c, 'inverseView'), false, inverse); g.uniform3fv(this.u(c, 'eye'), frame.eye); g.uniform2fv(this.u(c, 'screen'), [this.width, this.height]);
		g.uniformMatrix4fv(this.u(c, 'inverseSky'), false, frame.skyPerspective ? SourceModel.inverse(frame.skyPerspective) : inverse); g.uniform1i(this.u(c, 'flatSky'), frame.ortho && !frame.skyPerspective ? 1 : 0);
		g.uniform1f(this.u(c, 'outlinePx'), s.outlinePx || 1.2); g.uniform2fv(this.u(c, 'fx'), [s.outline && !s.realism ? 1 : 0, s.ao ? 1 : 0]); g.uniform1f(this.u(c, 'toonOn'), s.realism ? 0 : 1); g.uniform1f(this.u(c, 'ortho'), frame.ortho ? 1 : 0);
		g.drawArrays(g.TRIANGLES, 0, 3);
		this.presentExposure();
		return stats;
	}
	bind(program, list) { const g = this.gl; list.forEach(([name, texture], i) => { g.activeTexture(g.TEXTURE0 + i); g.bindTexture(g.TEXTURE_2D, texture); g.uniform1i(this.u(program, name), i); }); }
	dispose() {
		const g = this.gl; this.particles.dispose();this.destroyTargets();
		if (this.poseTarget) g.deleteFramebuffer(this.poseTarget);
		for (const b of this.buffers) g.deleteBuffer(b); for (const t of this.textures) g.deleteTexture(t); for (const p of this.programs) g.deleteProgram(p); for (const v of this.vaos) g.deleteVertexArray(v);
		for (const image of this.textureImages) delete image.gpu;
		this.models = {}; this.meshes.clear(); this.trails.clear(); this.textureImages.clear(); this.boneData = null; this.world = []; this.map = null; this.environment = null; this.exposureFrame = null; this.buffers = []; this.textures = []; this.programs = []; this.vaos = [];
	}
};
