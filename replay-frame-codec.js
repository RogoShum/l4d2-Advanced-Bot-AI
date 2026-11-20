'use strict';

// Web recordings keep independently seekable frames. Each chunk starts from the chapter's
// opening entity table. Later rows refer only to that entity's previous values in this chunk.
globalThis.ReplayFrameCodec = class {
	static scratch = new DataView(new ArrayBuffer(4));
	static bits(value) { this.scratch.setFloat32(0, value, true); return this.scratch.getUint32(0, true); }
	static number(bits) { this.scratch.setUint32(0, bits, true); return this.scratch.getFloat32(0, true); }
	static reference(key, state, time, fields) {
		if (!state) return undefined;
		const value = state.values[key], dt = time - state.time;
		if (key === fields.origin && value && dt > 0) {
			const velocity = state.values[fields.velocity];
			if (velocity) return value.map((v, i) => Math.fround(v + dt * velocity[i]));
		}
		if (key === fields.cycle && typeof value === 'number' && dt > 0) {
			const duration = state.values[fields.sequence]?.duration, rate = state.values[fields.rate];
			if (duration > 0 && Number.isFinite(rate)) return Math.fround((value + dt * rate / duration) % 1);
		}
		return value;
	}
	static opening(frame) { return new Map(frame[1].map(row => [row[0], {values:row.slice(2), time:frame[0]}])); }
	constructor(bytes, strings) { this.bytes = bytes; this.view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength); this.strings = strings; this.pos = 0; }
	byte() { return this.view.getUint8(this.pos++); }
	uint() {
		let n = 0, shift = 0, b;
		do { b = this.byte(); n |= (b & 127) << shift; shift += 7; } while (b & 128);
		return n >>> 0;
	}
	signed() { const n = this.uint(); return (n >>> 1) ^ -(n & 1); }
	float() { const x = this.view.getFloat32(this.pos, true); this.pos += 4; return x; }
	value(old) {
		const tag = this.byte();
		if (tag >= 16) { const n = tag - 16; return (n >>> 1) ^ -(n & 1); }
		switch (tag) {
		case 0: return null;
		case 1: return false;
		case 2: return true;
		case 3: return this.float();
		case 4: return this.signed();
		case 5: return this.strings[this.uint()];
		case 6: { const a = new Array(this.uint()); for (let i = 0; i < a.length; i++) a[i] = this.value(old?.[i]); return a; }
		case 7: {
			const obj = {}, n = this.uint();
			for (let i = 0; i < n; i++) { const key = this.strings[this.uint()]; Object.defineProperty(obj, key, {value:this.value(old?.[key]), writable:true, configurable:true, enumerable:true}); }
			return obj;
		}
		case 8: case 9: {
			const a = new Int32Array(this.uint());
			for (let i = 0; i < a.length; i++) a[i] = this.signed() + (tag === 9 ? old[i] : 0);
			return a;
		}
		case 10: return old;
		case 11: {
			const length = this.uint(), a = old.slice(0, length), n = this.uint(); a.length = length;
			for (let i = 0, at = -1; i < n; i++) { at += 1 + this.uint(); a[at] = this.value(old[at]); }
			return a;
		}
		case 12: {
			const obj = {...old}, removed = this.uint();
			for (let i = 0; i < removed; i++) delete obj[this.strings[this.uint()]];
			const n = this.uint();
			for (let i = 0; i < n; i++) { const key = this.strings[this.uint()]; Object.defineProperty(obj, key, {value:this.value(old[key]), writable:true, configurable:true, enumerable:true}); }
			return obj;
		}
		case 13: return ReplayFrameCodec.number(ReplayFrameCodec.bits(old) ^ this.uint());
		default: throw Error('录像分块编码无效');
		}
	}
	frames(names, base) {
		const fields = Object.fromEntries(names.map((name, i) => [name, i])), full = 2 ** names.length - 1, state = new Map(), frames = [];
		const n = this.uint(); let previousExtras = [];
		for (let f = 0; f < n; f++) {
			const time = this.float(), count = this.uint(), updates = []; let id = 0;
			for (let j = 0; j < count; j++) {
				id += this.signed();
				const mask = this.uint(), before = f ? state.get(id) : base?.get(id), values = before ? before.values.slice() : Array(names.length).fill(null);
				const expand = !f || !before, row = [id, expand ? full : mask];
				for (let k = 0; k < names.length; k++) {
					if (mask & (1 << k)) { values[k] = this.value(ReplayFrameCodec.reference(k, before, time, fields)); if (!expand) row.push(values[k]); }
				}
				if (expand) row.push(...values);
				updates.push(row); state.set(id, {values,time});
			}
			const extras = [];
			for (let i = 0; i < 5; i++) extras.push(this.value(previousExtras[i]));
			for (const gone of extras[0]) state.delete(gone);
			previousExtras = extras; frames.push([time, updates, ...extras]);
		}
		if (this.pos !== this.bytes.length) throw Error('录像分块长度无效');
		return frames;
	}
};
