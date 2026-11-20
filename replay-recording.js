'use strict';

globalThis.ReplayRecording = class {
	constructor(loader, id, manifest) { this.loader = loader; this.id = id; this.manifest = manifest; }
	read(time) { return this.loader.request('seek', {id:this.id, time}); }
	at(frame, time) {
		// The render clock can cross a flame hit before the next entity sample is installed.
		const flameHits = frame.events.filter(e => e.kind === 'damage_impact' && e.inflictor_class === 'entityflame' && e.t >= time - 1.5 && e.t <= frame.nextTime);
		return {...frame, t:time, flameHits, events:frame.events.filter(e => e.t >= time - 1.5 && e.t <= time + .1), deaths:this.manifest.deaths.filter(death => death.t <= time), trails:this.manifest.timeline.spriteTrails};
	}
	async seek(time) { return this.at(await this.read(time), time); }
	dispose() { if (this.loader) this.loader.request('release', {id:this.id}).catch(() => {}); this.loader = null; }
};

// Independent time blocks bound the decoded recording memory during playback and seek.
globalThis.ReplayChunks = class {
	constructor(source) { this.source = source; this.cache = new Map(); this.cursor = null; this.offset = 0; this.length = source.file?.size ?? source.size ?? Infinity; this.parts = new Map(); }
	async read(start, length) {
		if (start < 0 || length < 0 || start + length > this.length) throw Error('录像分段超出文件范围');
		start += this.offset;
		if (this.source.file) {
			// A recording still being written grows under the File snapshot, and Chrome then refuses to read that
			// snapshot (NotReadableError). Take a fresh one from the file handle and read again.
			try { return await this.source.file.slice(start, start + length).arrayBuffer(); }
			catch (error) {
				if (!this.source.handle) throw error;
				this.source.file = await this.source.handle.getFile();
				return this.source.file.slice(start, start + length).arrayBuffer();
			}
		}
		if (this.source.partSize) {
			const size = this.source.partSize, first = Math.floor(start / size), last = Math.floor((start + length - 1) / size);
			const pieces = await Promise.all(Array.from({length:last - first + 1}, async (_, n) => {
				const index = first + n;
				let part = this.parts.get(index);
				if (!part) {
					const url = new URL(this.source.url); url.pathname += '.' + index;
					part = fetch(url).then(async response => {
						if (!response.ok) throw Error('录像分片读取失败：HTTP ' + response.status);
						const bytes = new Uint8Array(await response.arrayBuffer());
						if (bytes.length !== Math.min(size, this.source.size - index * size)) throw Error('录像分片长度不符');
						return bytes;
					});
					part.catch(() => { if (this.parts.get(index) === part) this.parts.delete(index); });
				}
				this.parts.delete(index); this.parts.set(index,part);
				if (this.parts.size > 8) this.parts.delete(this.parts.keys().next().value);
				return (await part).subarray(Math.max(0,start - index * size),Math.min(size,start + length - index * size));
			}));
			const result = new Uint8Array(length); let pos = 0;
			for (const bytes of pieces) { result.set(bytes,pos); pos += bytes.length; }
			return result.buffer;
		}
		const response = await fetch(this.source.url, {headers:{Range:`bytes=${start}-${start + length - 1}`}});
		if (response.status !== 206) throw Error('录像读取需要本地服务支持分段读取：HTTP ' + response.status);
		const buffer = await response.arrayBuffer();
		if (buffer.byteLength !== length) throw Error('录像分段长度不符');
		return buffer;
	}
	async header() {
		const h = new DataView(await this.read(0, 16));
		return {magic:new TextDecoder().decode(new Uint8Array(h.buffer,0,8)), start:h.getUint32(8,true), size:h.getUint32(12,true)};
	}
	async readManifest({magic,start,size}) {
		if (magic.startsWith('{')) throw Error('这是正在录制的录像的实时索引（.live.l4d2replay），请在录像库里打开同名录像（标着“录制中”）');
		if (magic !== 'L4D2RPLZ' || start < 16 || !size) throw Error('请选择已结束的新格式单关录像');
		const bytes = await this.read(start,size);
		const manifest = await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate'))).json();
		if (manifest.frameEncoding?.codec !== 'zstd') throw Error('录像分块编码无效');
		return manifest;
	}
	static async pack(files) {
		if (files.length < 2) throw Error('请至少选择两份单关录像');
		const entries = [];
		for (const file of files) {
			const reader = new ReplayChunks({file}), header = await reader.header();
			if (header.magic === 'L4D2PACK') throw Error(file.name + ' 已是关卡包，请选择单关录像');
			const {map,duration} = await reader.readManifest(header);
			entries.push({file,chapter:{map,name:file.name,length:file.size,duration}});
		}
		entries.sort((a,b)=>a.chapter.map.localeCompare(b.chapter.map,'en',{numeric:true}) || a.file.name.localeCompare(b.file.name,'en',{numeric:true}));
		const chapters=entries.map(e=>e.chapter), index=new TextEncoder().encode(JSON.stringify(chapters)), header=new Uint8Array(16), h=new DataView(header.buffer);
		header.set(new TextEncoder().encode('L4D2PACK')); h.setUint32(8,16,true); h.setUint32(12,index.length,true);
		return {blob:new Blob([header,index,...entries.map(e=>e.file)],{type:'application/octet-stream'}),name:chapters[0].map+'-'+chapters.at(-1).map+'.l4d2replay'};
	}
	async open(chapter = 0) {
		let header = await this.header();
		if (header.magic === 'L4D2PACK') {
			const entries=JSON.parse(new TextDecoder().decode(await this.read(header.start,header.size)));
			if(!Array.isArray(entries) || !entries[chapter] || !entries.every(e=>e && typeof e.map==='string' && typeof e.name==='string' && Number.isSafeInteger(e.length) && e.length>=16)) throw Error('录像关卡索引无效');
			let at=header.start+header.size, chapterOffset=0;
			for (let i = 0; i < entries.length; i++) {
				const entry = entries[i];
				if (i === chapter) chapterOffset = at;
				if (!Number.isFinite(entry.duration) || entry.duration < 0) throw Error('关卡时长无效');
				at += entry.length;
			}
			if(!Number.isSafeInteger(at) || at>this.length)throw Error('录像关卡包不完整');
			this.chapters=entries;this.offset=chapterOffset;this.length=entries[chapter].length;header=await this.header();
		}
		// A recording still being written has no manifest yet (header offset 0): recording.py keeps a JSON
		// snapshot next to it, <name>.live.l4d2replay, whose chunk offsets point into this file.
		const manifest = header.magic === 'L4D2RPLZ' && !header.start && !header.size ? await this.readLive() : await this.readManifest(header);
		this.metadata = new Map(manifest.entities.map(entity => [entity.id, entity]));
		this.manifest = {fields:manifest.fields, chunks:manifest.chunks, duration:manifest.duration, frameEncoding:manifest.frameEncoding};
		this.throwables = [];
		for (const meta of manifest.entities) {
			const kind = meta.classname === 'vomitjar_projectile' ? 'bile' : meta.classname === 'pipe_bomb_projectile' ? 'pipe' : null;
			if (!kind) continue;
			const index = this.chunkAt(meta.end), block = manifest.chunks[index], duration = kind === 'bile' ? 20 : 4.8;
			// end is the last observation. The first absent sample can be the next block's keyframe.
			const latest = block.end > meta.end ? block.end : (manifest.chunks[index + 1]?.start ?? block.end);
			this.throwables.push({meta, kind, index, duration, latest:Math.fround(latest), impact:undefined});
		}
		const compressed = manifest.deaths.inline ? Uint8Array.from(atob(manifest.deaths.inline), c => c.charCodeAt(0)) : await this.read(manifest.deaths.offset, manifest.deaths.length), stream = new Blob([compressed]).stream().pipeThrough(new DecompressionStream('deflate'));
		manifest.deaths = ReplayChunks.decodeDeaths(await new Response(stream).arrayBuffer());
		manifest.bounds = [...manifest.bounds.min, ...manifest.bounds.max];
		return manifest;
	}
	async readLive() {
		if (this.source.live) {
			// The recorder replaces the live index every 5 s; a snapshot taken just before is then unreadable.
			try { return JSON.parse(await this.source.live.text()); }
			catch (error) { if (!this.source.liveHandle) throw error; return JSON.parse(await (await this.source.liveHandle.getFile()).text()); }
		}
		if (!this.source.url) throw Error('这份录像还在录制中，但没有找到它的实时索引：请从录像库打开（标着“录制中”）');
		const url = new URL(this.source.url, self.location.href), path = url.searchParams.get('path'), live = name => name.replace(/\.l4d2replay$/i, '.live.l4d2replay');
		if (path) url.searchParams.set('path', live(path)); else url.pathname = live(url.pathname);
		const response = await fetch(url, {cache:'no-store'});
		if (!response.ok) throw Error('这份录像还在录制中，但没有实时索引（录制刚开始时，请等第一段写完再打开）');
		const manifest = await response.json();
		this.length = Infinity;
		return manifest;
	}
	static decodeDeaths(buffer) {
		const view = new DataView(buffer), bytes = new Uint8Array(buffer), decoder = new TextDecoder(); let offset = 0;
		const count = () => { let value = 0, shift = 0, byte; do { byte = view.getUint8(offset++); value |= (byte & 127) << shift; shift += 7; } while (byte & 128); return value >>> 0; };
		function value() {
			const tag = view.getUint8(offset++);
			if (tag === 0) return null;
			if (tag === 1) return false;
			if (tag === 2) return true;
			if (tag === 3) { const result = view.getInt32(offset, true); offset += 4; return result; }
			if (tag === 4) { const result = view.getFloat32(offset, true); offset += 4; return result; }
			if (tag === 5) { const length = count(), result = decoder.decode(bytes.subarray(offset, offset + length)); offset += length; return result; }
			if (tag === 6) { const result = new Array(count()); for (let i = 0; i < result.length; i++) result[i] = value(); return result; }
			if (tag === 7) { const result = {}, length = count(); for (let i = 0; i < length; i++) { const key = value(); result[key] = value(); } return result; }
			if (tag === 8) { const result = new Int32Array(count()); for (let i = 0; i < result.length; i++) { const encoded = count(); result[i] = (encoded >>> 1) ^ -(encoded & 1); } return result; }
			throw Error('录像数据字段损坏');
		}
		return value();
	}
	// Range reads share one promise per cached chunk.
	block(index) {
		if (!this.cache.has(index)) {
			const entry = this.manifest.chunks[index];
			const pending = (async () => {
				const packing = this.manifest.frameEncoding;
				if (index && !this.opening) await this.block(0);
				const bytes = await this.read(entry.offset, entry.length);
				this.zstd ||= ReplayZstd();
				const reader = new ReplayFrameCodec(this.zstd(new Uint8Array(bytes)),packing.strings);
				const frames = reader.frames(this.manifest.fields,index ? this.opening : null);
				if (!index) this.opening = ReplayFrameCodec.opening(frames[0]);
				return frames;
			})();
			pending.catch(() => this.cache.get(index) === pending && this.cache.delete(index));
			this.cache.set(index, pending);
		}
		return this.cache.get(index);
	}
	prefetch(index) { for (const next of [index + 1, index + 2]) if (next < this.manifest.chunks.length && !this.cache.has(next)) this.block(next).catch(() => {}); }
	apply(frame, state) {
		for (const id of frame[2]) state.delete(id);
		for (const update of frame[1]) {
			const [id, mask] = update, entity = {...(state.get(id) || this.metadata.get(id))}; let value = 2;
			for (let i = 0; i < this.manifest.fields.length; i++) if (mask & (1 << i)) entity[this.manifest.fields[i]] = update[value++];
			if (entity.classname === 'player' && entity.active !== state.get(id)?.active) entity.activeSince = frame[0];
			state.set(id, entity);
		}
	}
	chunkAt(time) {
		const entries = this.manifest.chunks; let lo = 0, hi = entries.length;
		while (lo < hi) { const mid = (lo + hi) >>> 1; if (Math.fround(entries[mid].start) <= time) lo = mid + 1; else hi = mid; }
		return Math.max(0, lo - 1);
	}
	async commonMotion(index) {
		const block = await this.block(index);
		if (block.commonMotion) return block.commonMotion;
		const first = block[0][0], end = block.at(-1)[0], limit = .55, fixes = new Map(), states = new Map(), anchors = new Map();
		const same = (a,b) => a===b || a?.length===b?.length && a?.every((v,i)=>v===b[i]);
		const previous=index ? await this.block(index-1) : [], frames = [...previous, ...block];
		if (index+1<this.manifest.chunks.length) frames.push(...(await this.block(index+1)).filter(f=>f[0]<=end+limit));
		for (let n=0;n<frames.length;n++) {
			const [time,updates,removed]=frames[n];
			// A chunk starts with a full snapshot, including after a seek. Gaps in presence break a run.
			if (n===previous.length || n===previous.length+block.length) states.clear();
			for (const id of removed) { states.delete(id); anchors.delete(id); }
			const changes=updates.filter(u=>this.metadata.get(u[0])?.classname==='infected');
			this.apply([time,changes,[]],states);
			for (const [id] of changes) {
				const b=states.get(id), prior=anchors.get(id), a=prior?.state;
				if (a && a.model===b.model && a.life===b.life && a.sequence?.index===b.sequence?.index && a.cycle===b.cycle && same(a.origin,b.origin) && same(a.angles,b.angles) && same(a.render?.bones,b.render?.bones) && same(a.pose,b.pose) && same(a.velocity,b.velocity)) continue;
				anchors.set(id,{state:b,n});
				if (!a || a.life!==0 || b.life!==0 || a.model!==b.model || !a.sequence || a.sequence.index!==b.sequence?.index || n<=prior.n+1) continue;
				const start=frames[prior.n][0], dt=time-start;
				if (dt>limit || time<=first || start>=end || !a.velocity || !b.velocity || !a.origin || !b.origin) continue;
				const speed=Math.hypot(...a.velocity), distance=Math.hypot(...b.origin.map((v,k)=>v-a.origin[k]));
				if (speed<8 || Math.hypot(...b.velocity)<8 || distance<1 || distance>8+dt*Math.max(speed,Math.hypot(...b.velocity))*2) continue;
				const bones=a.render?.bones, nextBones=b.render?.bones;
				if (bones?.length!==nextBones?.length) continue;
				const delta=b.cycle-a.cycle, phase=delta<-.5?delta+1:delta;
				if (phase<0) continue;
				for (let i=prior.n+1;i<n;i++) {
					const t=frames[i][0]; if(t<first||t>end)continue;
					const f=(t-start)/dt, mix=(v,w)=>v+(w-v)*f, angle=(v,w,turn)=>v+(((w-v+turn*1.5)%turn)-turn*.5)*f;
					const pose={origin:a.origin.map((v,k)=>mix(v,b.origin[k])), angles:a.angles.map((v,k)=>angle(v,b.angles[k],360)),cycle:(a.cycle+phase*f)%1};
					if(a.pose&&a.pose.length===b.pose?.length)pose.pose=a.pose.map((v,k)=>mix(v,b.pose[k]));
					if(bones)pose.bones=Int32Array.from(bones,(v,k)=>Math.round(k%6<3?mix(v,nextBones[k]):angle(v,nextBones[k],360*128)));
					let row=fixes.get(t);if(!row)fixes.set(t,row=new Map());row.set(id,pose);
				}
			}
			for(const id of anchors.keys())if(!states.has(id))anchors.delete(id);
		}
		return block.commonMotion=fixes;
	}
	async impact(item) {
		const {meta, index, kind} = item, frames = await this.block(index), end = Math.fround(meta.end);
		const pos = frames.findIndex(frame => frame[0] === end), last = frames[pos];
		if (!last) return null;
		const across = pos === frames.length - 1, next = across && index + 1 < this.manifest.chunks.length ? (await this.block(index + 1))[0] : frames[pos + 1];
		const sample = kind === 'bile' ? 'weapons/ceda_jar/ceda_jar_explode.wav' : 'weapons/hegrenade/explode3.wav';
		const sound = [...last[3], ...(next?.[3] || [])].find(event => event.kind === 'sound' && !(event.flags & 4) && event.sample?.toLowerCase() === sample && (event.id != null ? event.id === meta.id : event.entity === meta.entity) && event.t >= Math.fround(meta.start));
		if (!sound && !next) return null; // The recording ended while the projectile was still present.
		const t = sound?.t ?? next[0], before = new Map();
		for (let i = 0; i <= pos; i++) this.apply(frames[i], before);
		const origin = sound?.origin ?? before.get(meta.id)?.origin;
		if (!origin) return null;
		const nearby = [];
		if (kind === 'bile') {
			// Use the two samples bracketing impact, independent of the playback cursor or camera.
			let left = before, right = before, a = last[0], b = a;
			if (t >= a && next) { right = across ? new Map() : new Map(before); this.apply(next, right); b = next[0]; }
			else if (t < a) {
				const previous = pos ? frames : index ? await this.block(index - 1) : null;
				const previousPos = pos ? pos - 1 : previous ? previous.length - 1 : -1;
				if (previousPos >= 0) { left = new Map(); for (let i = 0; i <= previousPos; i++) this.apply(previous[i], left); b = a; a = previous[previousPos][0]; }
			}
			const blend = b > a ? Math.min(1, Math.max(0, (t - a) / (b - a))) : 0;
			for (const state of (blend >= 1 ? right : left).values()) {
				if ((state.classname !== 'infected' && state.classname !== 'witch') || state.life !== 0 || !state.origin) continue;
				const other = right.get(state.id), center = state.origin.map((v, k) => v + (other && blend < 1 ? (other.origin[k] - v) * blend : 0) + (state.hull ? (state.hull.mins[k] + state.hull.maxs[k]) / 2 : 0));
				// Common infected have no recorded bile timer. Estimate exposure from sampled positions.
				if (Math.hypot(...center.map((v, k) => v - origin[k])) <= 110) nearby.push(state.id);
			}
		}
		return {id:meta.id, kind, t, origin, until:t + item.duration, timeSource:sound ? 'sound' : 'disappearance', originSource:sound?.origin ? 'sound' : 'lastSample', nearby};
	}
	drawPlan(entities) {
		const opaque = new Map(), blended = [];
		for (const state of entities) {
			const groups = this.drawModels[state.model]; if (!groups || !state.render || state.render.effects & 32 || state.render.mode === 10) continue;
			const alpha = state.render.color >>> 24;
			for (const group of groups) {
				if (group.base && Math.floor((state.body || 0) / group.base) % group.variants !== group.variant) continue;
				const skin = state.skin || 0, cmd = skin >= 0 && skin < group.skins.length ? group.skins[skin] : group.defaultSkin; if (!cmd) continue;
				if (cmd.blend || alpha < 255 || [3,5,9].includes(state.render.mode)) { blended.push([cmd.mesh, state.id]); continue; }
				let ids = opaque.get(cmd); if (!ids) opaque.set(cmd, ids = [cmd.mesh]); ids.push(state.id);
			}
		}
		return {opaque:[...opaque.keys()].sort((a,b) => a.material-b.material || a.geometry-b.geometry).map(cmd => opaque.get(cmd)), blended};
	}
	async seek(time) {
		const entries = this.manifest.chunks, index = this.chunkAt(time), frames = await this.block(index); let lo = 0, hi = frames.length;
		while (lo < hi) { const mid = (lo + hi) >>> 1; if (frames[mid][0] <= time) lo = mid + 1; else hi = mid; }
		const position = Math.max(0, lo - 1);
		if (!this.cursor || this.cursor.index !== index || this.cursor.position > position) {
			const state=new Map();
			if(index){
				for(const [t,updates,removed] of await this.block(index-1)) this.apply([t,updates.filter(u=>this.metadata.get(u[0])?.classname==='player'),removed],state);
				const present=new Set(frames[0][1].map(u=>u[0])); for(const id of state.keys()) if(!present.has(id))state.delete(id);
			}
			this.cursor = {index, position:-1, state, objective:null, environment:null, botai:new Map()};
		}
		const cursor = this.cursor;
		for (let i = cursor.position + 1; i <= position; i++) { this.apply(frames[i], cursor.state); if (frames[i][4] !== null) cursor.objective = frames[i][4]; if (frames[i][5] !== null) cursor.environment = frames[i][5]; if (frames[i][6]) ReplayChunks.decisions(cursor.botai, frames[i][6], frames[i][0]); }
		cursor.position = position;
		let next = frames[position + 1], nextState = new Map(cursor.state);
		const across = !next && index + 1 < entries.length;
		if (across) { next = (await this.block(index + 1))[0]; nextState.clear(); }
		if (next) this.apply(next, nextState);
		const sampleTime = frames[position][0], nextTime = next ? next[0] : this.manifest.duration + 1;
		const isBeep = event => event.t >= sampleTime - 1.5 && event.t <= nextTime && event.kind === 'sound' && !(event.flags & 4) && event.sample?.toLowerCase() === 'weapons/hegrenade/beep.wav';
		const localEvents = frames.flatMap(frame => frame[3]), pipeBeeps = localEvents.filter(isBeep), events = localEvents.filter(event => event.t >= sampleTime - 1.5 && event.t <= nextTime + .1);
		if (across) pipeBeeps.push(...next[3].filter(isBeep));
		if (sampleTime - Math.fround(entries[index].start) < 1.5 && index > 0) {
			const previousEvents = (await this.block(index - 1)).flatMap(frame => frame[3]);
			events.unshift(...previousEvents.filter(event => event.t >= sampleTime - 1.5 && event.t < entries[index].start));
			pipeBeeps.push(...previousEvents.filter(isBeep));
		}
		const throwables = [];
		for (const item of this.throwables) {
			if (Math.fround(item.meta.end) > nextTime || item.latest + item.duration < time) continue;
			if (item.impact === undefined) item.impact = await this.impact(item);
			if (item.impact && item.impact.t <= nextTime && item.impact.until >= time) throwables.push(item.impact);
		}
		for (const key of [...this.cache.keys()]) if (key < index - 1 || key > index + 2) this.cache.delete(key);
		this.prefetch(index);
		const motion=await this.commonMotion(index), following=across?await this.commonMotion(index+1):motion;
		const display=(states,row)=>Array.from(states.values(),s=>{
			const fix=row?.get(s.id);if(!fix)return s;
			const {bones,...pose}=fix;return bones?{...s,...pose,render:{...s.render,bones}}:{...s,...pose};
		});
		const entities = display(cursor.state,motion.get(sampleTime));
		return {t:time, sampleTime, nextTime, entities, nextEntities:display(nextState,following.get(nextTime)), draws:this.drawModels && this.drawPlan(entities), events, throwables, pipeBeeps, objective:cursor.objective, environment:cursor.environment, botai:cursor.botai.size ? [...cursor.botai.values()] : null};
	}
	// BotAI decision records (recording.py decisions()): merge changed parts per bot, remember
	// when each part was sampled, and derive nodes that were running and are no longer visited.
	static decisions(bots, records, time) {
		for (const record of records) {
			if (record.gone) { bots.delete(record.u); continue; }
			const previous = bots.get(record.u), next = {...previous, ...record, sampled:time, since:{...previous?.since}};
			for (const key of ['n', 'q', 'm', 'r', 'v', 't']) if (key in record) next.since[key] = time;
			if (record.n && previous?.n) {
				const now = new Set(record.n.map(code => code >> 2)), aborted = [];
				for (const code of previous.n) if ((code & 3) === 2 && !now.has(code >> 2)) aborted.push(code >> 2);
				next.aborted = aborted; next.abortedAt = time;
			} else if (record.n) { next.aborted = []; }
			bots.set(record.u, next);
		}
	}
	dispose() { this.cache.clear(); this.parts.clear(); this.opening = null; this.cursor = null; this.throwables.length = 0; this.metadata.clear(); this.source = null; this.manifest = null; }
};
