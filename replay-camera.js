'use strict';
globalThis.ReplayCamera = class {
	constructor(canvas, bounds, world, actors, invalidate, signal) {
		this.canvas = canvas; this.bounds = bounds; this.actors = actors; this.invalidate = invalidate;
		this.depthBounds = bounds.slice();
		for (const chunk of world) if (!chunk.material?.sky) for (let k = 0; k < 3; k++) {
			this.depthBounds[k] = Math.min(this.depthBounds[k], chunk.bounds[k]);
			this.depthBounds[k+3] = Math.max(this.depthBounds[k+3], chunk.bounds[k+3]);
		}
		this.mode = 'orbit'; this.yaw = -1.5; this.pitch = .78; this.distance = 900; this.target = [0, 0, 0]; this.follow = 'team'; this.snap = true; this.flySpeed = 500; this.cutBase = 0; this.keys = new Set();
		for (const button of document.querySelectorAll('[data-camera]')) button.onclick = () => this.setMode(button.dataset.camera);
		$('followTeam').onclick = () => this.followActor('team', Math.max(this.distance, 750));
		$('whole').onclick = () => this.wholeMap();
		canvas.style.touchAction = 'none';
		canvas.addEventListener('pointerdown', e => { e.preventDefault(); canvas.focus(); closePops(); this.drag = [e.clientX, e.clientY, e.button, e.shiftKey]; canvas.setPointerCapture(e.pointerId); }, {signal});
		for (const type of ['pointerup', 'pointercancel', 'lostpointercapture']) canvas.addEventListener(type, () => this.drag = null, {signal});
		canvas.addEventListener('contextmenu', e => e.preventDefault(), {signal});
		canvas.addEventListener('pointermove', e => this.pointerMove(e), {signal});
		canvas.addEventListener('wheel', e => { e.preventDefault(); if (this.mode === 'first') return; const dy = e.deltaY * (e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? canvas.clientHeight : 1); if (this.mode === 'fly' && !this.ortho) { this.flySpeed = clamp(this.flySpeed * Math.exp(-dy * .001), 30, 3000); hint('飞行速度 ' + Math.round(this.flySpeed) + ' u/s', 1200); } else this.distance = clamp(this.distance * Math.exp(dy * .001), 50, 30000); invalidate(); }, {passive:false, signal});
		window.addEventListener('keyup', e => this.keys.delete(e.code), {signal});
		window.addEventListener('blur', () => { this.keys.clear(); this.drag = null; }, {signal}); canvas.addEventListener('blur', () => this.keys.clear(), {signal});
		this.setMode('orbit');
	}
	setMode(mode) {
		if (mode === 'first') {
			const players = this.actors().filter(a => this.hasEye(a)), player = players.find(a => a.id === this.follow) || players.find(a => a.team === 2);
			if (!player) { hint('当前没有可用的角色视角', 1200); return; }
			this.mode = mode; this.follow = player.id; this.placeEye(player.eye); this.keys.clear();
		}
		if (mode === 'fly' && this.mode !== 'fly') { const eye = this.eye(); this.cutBase = this.target[2]; if (this.mode === 'top') this.pitch = 1.55; this.mode = mode; const back = this.back(); this.target = eye.map((v, i) => v - back[i] * this.distance); this.follow = 'free'; this.keys.clear(); this.canvas.focus(); hint('飞行：WASD 移动 · Q/E 下降/上升 · Shift 加速 · 右键拖动转头 · 滚轮' + (this.ortho ? '缩放' : '调速')); }
		else if (mode === 'orbit') { if (this.mode !== mode) this.pitch = .78; this.mode = mode; }
		else if (mode === 'top') { this.mode = mode; this.distance = Math.min(this.distance, 2400); }
		for (const button of document.querySelectorAll('[data-camera]')) button.classList.toggle('on', button.dataset.camera === this.mode);
		$('followTeam').classList.toggle('on', this.follow === 'team'); this.invalidate();
	}
	hasEye(a) { return a?.classname === 'player' && (a.life === 0 || a.life === 3) && a.eye?.origin && a.eye.angles; }
	eyeAt(player, next, t) {
		const a = player.eye;
		if (!t || !this.hasEye(next) || player.model !== next.model || Math.hypot(...next.eye.origin.map((v,i)=>v-a.origin[i])) >= 128) return a;
		const b = next.eye;
		return {origin:a.origin.map((x, i) => x + (b.origin[i] - x) * t), angles:a.angles.map((x, i) => x + (((b.angles[i] - x) % 360 + 540) % 360 - 180) * t)};
	}
	placeEye({origin, angles}) {
		this.firstEye = origin;
		this.yaw = angles[1] * Math.PI / 180 + Math.PI; this.pitch = angles[0] * Math.PI / 180; this.roll = (angles[2] || 0) * Math.PI / 180;
		const back = this.back(); this.target = this.firstEye.map((x, i) => x - back[i]);
	}
	updateEye(frame, time) {
		const a = frame.prepared.states.get(this.follow);
		if (!this.hasEye(a)) { this.setMode('first'); if (!this.hasEye(frame.prepared.states.get(this.follow))) this.followActor('team'); return; }
		const b = frame.prepared.next.get(a.id), t = clamp((time - frame.sampleTime) / (frame.nextTime - frame.sampleTime || 1), 0, 1);
		this.placeEye(this.eyeAt(a, b, t));
	}
	followPoint(id) {
		if (id === 'free') return null;
		const actors = this.actors().filter(a => a.origin && (id === 'team' ? a.team === 2 : a.id === id));
		return actors.length ? [0, 1, 2].map(k => actors.reduce((sum, a) => sum + a.origin[k], 0) / actors.length + (k === 2 ? 30 : 0)) : null;
	}
	followActor(id, distance) {
		this.follow = id; this.snap = Math.hypot(...this.target.map((v, k) => v - (this.followPoint(id) || this.target)[k])) > 1500;
		if (this.mode === 'fly' || (this.mode === 'first' && id === 'team')) { this.mode = 'orbit'; this.pitch = .78; } if (distance) this.distance = distance; this.setMode(this.mode);
	}
	wholeMap() {
		this.follow = 'free'; this.target = this.bounds.slice(0, 3).map((v, i) => (v + this.bounds[i + 3]) / 2); this.keys.clear();
		const ext = Math.max(this.bounds[3] - this.bounds[0], this.bounds[4] - this.bounds[1]) / 2;
		this.setMode('top'); this.distance = Math.max(ext, ext / (this.canvas.width / this.canvas.height)) / .55 * 1.12 + 150;
		prefs.slice = false; $('slice').checked = false;
	}
	moveTo(x, y) { this.target[0] = x; this.target[1] = y; this.follow = 'free'; if (this.mode === 'fly' || this.mode === 'first') this.setMode('orbit'); this.distance = Math.min(this.distance, 1400); $('followTeam').classList.remove('on'); this.invalidate(); }
	pointerMove(e) {
		const drag = this.drag; if (!drag || this.mode === 'first') return; const dx = e.clientX - drag[0], dy = e.clientY - drag[1];
		if (this.mode === 'fly' && drag[2] !== 1) { const eye = this.eye(); this.yaw -= dx * .003; this.pitch = this.ortho ? this.pitch + dy * .003 : clamp(this.pitch + dy * .003, -1.55, 1.55); const back = this.back(); this.target = eye.map((v, i) => v - back[i] * this.distance); }
		else if (drag[2] === 1 || drag[2] === 2 || drag[3] || this.mode === 'top') {
			this.follow = 'free'; $('followTeam').classList.remove('on'); const phi = this.viewPitch, yaw = this.yaw, k = 2 * this.distance * (this.ortho ? .55 : Math.tan(.52)) / this.canvas.clientHeight;
			const right = [-Math.sin(yaw), Math.cos(yaw), 0], up = [-Math.sin(phi) * Math.cos(yaw), -Math.sin(phi) * Math.sin(yaw), Math.cos(phi)], delta = right.map((v, i) => (-v * dx + up[i] * dy) * k);
			this.target = this.target.map((v, i) => v + delta[i]); if (this.mode === 'fly') this.cutBase += delta[2];
		} else { this.yaw -= dx * .004; this.pitch = this.ortho ? this.pitch + dy * .004 : clamp(this.pitch + dy * .004, -1.55, 1.55); }
		drag[0] = e.clientX; drag[1] = e.clientY; this.invalidate();
	}
	handleKey(e) {
		if (this.mode !== 'fly' || !['KeyW', 'KeyA', 'KeyS', 'KeyD', 'KeyQ', 'KeyE', 'ShiftLeft', 'ShiftRight'].includes(e.code)) return false;
		e.preventDefault(); this.keys.add(e.code); return true;
	}
	update(dt) {
		if (this.mode === 'first') return;
		if (this.mode === 'fly' && this.keys.size) {
			const back = this.back(), right = [-Math.sin(this.yaw), Math.cos(this.yaw), 0], forward = Number(this.keys.has('KeyW')) - Number(this.keys.has('KeyS')), side = Number(this.keys.has('KeyD')) - Number(this.keys.has('KeyA')), vertical = Number(this.keys.has('KeyE')) - Number(this.keys.has('KeyQ'));
			const delta = back.map((v, i) => -v * forward + right[i] * side + (i === 2 ? vertical : 0)), length = Math.hypot(...delta);
			if (length) {
				const s = this.flySpeed * (this.keys.has('ShiftLeft') || this.keys.has('ShiftRight') ? 3 : 1) * dt / length, previous = this.distance;
				// Make vertical motion visible even when looking straight down, keeping the eye on its vertical path.
				if (vertical && this.ortho) this.distance = clamp(previous + vertical * s * back[2], 50, 30000);
				const previousZ = this.target[2];
				this.target = this.target.map((v, i) => v + delta[i] * s - back[i] * (this.distance - previous)); this.cutBase += this.target[2] - previousZ; this.invalidate();
			}
		}
		const want = this.followPoint(this.follow); if (!want) return;
		const gap = Math.hypot(...want.map((v, k) => v - this.target[k]));
		if (this.snap || gap > 1500 || dt === 0) { this.target = want; this.snap = false; this.invalidate(); return; }
		if (gap < .05) return; const k = 1 - Math.exp(-dt * 9); this.target = this.target.map((v, i) => v + (want[i] - v) * k); this.invalidate();
	}
	get ortho() { return this.mode === 'top' || prefs.isometric && (this.mode === 'orbit' || this.mode === 'fly'); }
	get viewPitch() { return this.mode === 'top' ? 1.569 : this.pitch; }
	back() { const phi = this.viewPitch, yaw = this.yaw; return [Math.cos(phi) * Math.cos(yaw), Math.cos(phi) * Math.sin(yaw), Math.sin(phi)]; }
	eye() { return this.mode === 'first' ? this.firstEye : this.back().map((v, i) => this.target[i] + this.distance * v); }
	view(aspect, ortho = this.ortho) {
		const eye = this.eye(), z = this.back(), right = [-Math.sin(this.yaw), Math.cos(this.yaw), 0], up = ReplayCamera.cross(z, right), roll = this.mode === 'first' ? this.roll : 0, x = roll ? right.map((v,i)=>v*Math.cos(roll)-up[i]*Math.sin(roll)) : right, y = ReplayCamera.cross(z, x), dot = (a, b) => a.reduce((sum, v, i) => sum + v * b[i], 0);
		const view = new Float32Array([x[0], y[0], z[0], 0, x[1], y[1], z[1], 0, x[2], y[2], z[2], 0, -dot(x, eye), -dot(y, eye), -dot(z, eye), 1]); let projection;
		if (ortho) {
			// Fit the playable world along the parallel rays, with room for models beyond their recorded origins.
			const b = this.depthBounds, h = this.distance * .55, w = h * aspect; let near = -128, far = 128;
			for (let k = 0; k < 3; k++) {
				near += (eye[k] - b[k + (z[k] >= 0 ? 3 : 0)]) * z[k];
				far += (eye[k] - b[k + (z[k] >= 0 ? 0 : 3)]) * z[k];
			}
			projection = new Float32Array([1 / w, 0, 0, 0, 0, 1 / h, 0, 0, 0, 0, -2 / (far - near), 0, 0, 0, -(far + near) / (far - near), 1]);
		} else {
			const near = this.mode === 'first' || this.mode === 'top' ? 2 : Math.max(2, Math.min(8, this.distance * .01)), far = 40000, q = 1 / Math.tan(this.mode === 'first' ? prefs.firstFov * Math.PI / 360 : .52);
			projection = new Float32Array([q / aspect, 0, 0, 0, 0, q, 0, 0, 0, 0, (far + near) / (near - far), -1, 0, 0, 2 * far * near / (near - far), 0]);
		}
		return SourceModel.multiply(projection, view);
	}
	static norm(a) { const n = Math.hypot(...a) || 1; return a.map(v => v / n); }
	static cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
};
