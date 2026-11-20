'use strict';
async function startReplay(recording, map, models, file, renderer, campaign, start = 0, autoplay = false, initialSpeed = 1) {
	document.body.classList.remove('empty');
	const manifest = recording.manifest, listeners = new AbortController(), signal = listeners.signal, canvas = $('world'), overlay = $('overlay'), speeds = [.25, .5, 1, 2, 4, 8];
	start = clamp(start,0,manifest.summary.duration);
	let frame = await recording.seek(start), time = start, desiredTime = start, speed = initialSpeed, playing = autoplay, dirty = true, last = 0, animationFrame = 0, pending = null, disposed = false, generation = 0, lastStats = null, jump = false;
	const invalidate = () => dirty = true, camera = new ReplayCamera(canvas, manifest.bounds, map.world, () => frame.entities, invalidate, signal);
	const actions = {camera, campaign, seek:setTime, seekCampaign, follow:(id, distance) => camera.followActor(id, distance)}, ui = new ReplayUI(manifest, actions, signal, map.hudIcons), scene = new ReplayScene(manifest, map, models, renderer, ui, camera, recording.loader);
	await scene.prepareFrame(frame); scene.setFrame(frame, true); camera.update(0);
	const audio = new ReplayAudio(manifest, path => recording.loader.request('file', {path}), ui); hooks.audio = audio; if (prefs.audio && navigator.userActivation?.hasBeenActive) audio.enable();
	function setSpeed(value) { speed = value; for (const button of $('speeds').children) button.classList.toggle('on', Number(button.dataset.speed) === value); }
	// The button always shows `playing`; it is re-synced every frame, so no code path
	// (error, end of recording, a new recording, a seek) can leave it showing the other state.
	let shownPlaying = null;
	function syncPlayButton() { if (shownPlaying === playing) return; shownPlaying = playing; const button = $('play'); button.querySelector('use').setAttribute('href', playing ? '#i-pause' : '#i-play'); button.setAttribute('aria-pressed', String(playing)); button.title = (playing ? '暂停' : '播放') + ' (空格)'; }
	let ahead = null;
	function prefetch() {
		if (ahead || disposed || frame.nextTime > manifest.summary.duration) return;
		const entry = ahead = {time:frame.nextTime};
		entry.promise = recording.read(entry.time).then(async next => {
			if (entry !== ahead || disposed) return;
			await scene.prepareFrame(next); if(entry===ahead && !disposed)entry.frame=next;
		}).catch(error => { entry.error = error; });
	}
	function install(next, at, seek) {
		ahead = null; frame = recording.at(next, at); time = at; scene.setFrame(frame, seek); invalidate(); prefetch();
	}
	function setPlaying(value) { playing = !!value; if (playing && campaign.offset + desiredTime >= campaign.duration) seekCampaign(0); else if (playing) prefetch(); syncPlayButton(); }
	async function readTime() {
		while (!disposed) {
			const token = generation, requested = desiredTime, seek = jump;
			const entry = !seek && ahead;
			if (entry && requested >= entry.time) await entry.promise;
			if (disposed) return; if (token !== generation) continue;
			if (entry?.error) throw entry.error;
			const cached = entry?.frame, next = cached && requested >= cached.sampleTime && requested < cached.nextTime ? cached : await recording.read(requested); if (disposed) return;
			if(token!==generation)continue;
			if(!next.prepared)await scene.prepareFrame(next);
			if(disposed)return;
			if (token !== generation) continue;
			jump = false; install(next, requested, seek); break;
		}
	}
	function seekCampaign(seconds) {
		const at = clamp(seconds,0,campaign.duration);
		let chapter = campaign.entries.length - 1;
		while (chapter > 0 && at < campaign.entries[chapter].start) chapter--;
		if (chapter === campaign.index) return setTime(at - campaign.offset);
		const resume = playing; playing = false;
		return campaign.change(chapter,at - campaign.entries[chapter].start,resume,speed).catch(showError);
	}
	function requestTime() {
		if (pending) return pending;
		const timer = setTimeout(() => { if (!disposed) $('replayBuffer').hidden = false; },160);
		pending = readTime().catch(error => { if (!disposed) { showError(error); setPlaying(false); } }).finally(() => {
			clearTimeout(timer);
			if (!disposed) { $('replayBuffer').hidden = true; last = performance.now(); }
			pending = null;
		}); return pending;
	}
	function setTime(value) { desiredTime = clamp(value, 0, manifest.summary.duration); generation++; jump = true; ahead = null; scene.jobs?.reset(); return requestTime(); }
	$('speeds').replaceChildren(...speeds.map(value => { const button = replayNode('button', 'btn', value + '×'); button.dataset.speed = value; button.onclick = () => setSpeed(value); return button; })); setSpeed(initialSpeed);
	syncPlayButton(); $('play').onclick = () => setPlaying(!playing); $('back').onclick = () => seekCampaign(campaign.offset + time - 5); $('fwd').onclick = () => seekCampaign(campaign.offset + time + 5);
	function dockSpace() { document.documentElement.style.setProperty('--dock-space', ($('dock').offsetHeight + 24) + 'px'); }
	function resize() { const dpr = Math.min(devicePixelRatio || 1, 2), scale = dpr * prefs.scale; canvas.width = Math.max(1, Math.round(canvas.clientWidth * scale)); canvas.height = Math.max(1, Math.round(canvas.clientHeight * scale)); overlay.width = Math.round(canvas.clientWidth * dpr); overlay.height = Math.round(canvas.clientHeight * dpr); ui.drawTimeline(); dockSpace(); invalidate(); }
	hooks.invalidate = invalidate; hooks.layout = resize; window.addEventListener('resize', resize, {signal}); resize(); const watch = new ResizeObserver(dockSpace); watch.observe($('dock')); signal.addEventListener('abort', () => watch.disconnect());
	window.addEventListener('keydown', event => {
		if (event.ctrlKey || event.metaKey || event.altKey || event.target.matches('input:not([type=checkbox]),select,textarea') || event.target.isContentEditable || camera.handleKey(event)) return;
		const step = 1 / manifest.summary.tickrate, handled = {
			Space:() => { if (!event.repeat) setPlaying(!playing); }, ArrowRight:() => seekCampaign(campaign.offset + time + (event.shiftKey ? 5 : 1)), ArrowLeft:() => seekCampaign(campaign.offset + time - (event.shiftKey ? 5 : 1)), Period:() => { setPlaying(false); seekCampaign(campaign.offset + time + step); }, Comma:() => { setPlaying(false); seekCampaign(campaign.offset + time - step); },
			BracketRight:() => setSpeed(speeds[Math.min(speeds.length - 1, speeds.indexOf(speed) + 1)]), BracketLeft:() => setSpeed(speeds[Math.max(0, speeds.indexOf(speed) - 1)]), KeyN:() => ui.stepEvent(1), KeyP:() => ui.stepEvent(-1), KeyC:() => camera.setMode(camera.mode === 'top' ? 'orbit' : 'top'), KeyF:() => camera.wholeMap(),
			KeyE:() => setDrawer(!prefs.drawer), KeyM:() => setMini(!prefs.mini), KeyL:() => togglePop('layersBtn', 'layersPop'), KeyT:() => { const values = ['0', '3', '8', '20', '60', 'all']; prefs.trail = values[(values.indexOf(prefs.trail) + 1) % values.length]; $('trail').value = prefs.trail; savePrefs(); hint('轨迹：' + $('trail').selectedOptions[0].text, 1200); invalidate(); },
			KeyX:() => { prefs.xray = !prefs.xray; $('xray').checked = prefs.xray; savePrefs(); hint('穿墙显示：' + (prefs.xray ? '开' : '关'), 1200); invalidate(); }, KeyH:() => { document.body.classList.toggle('noui'); invalidate(); }, Slash:() => togglePop('helpBtn', 'helpPop'), Digit0:() => camera.followActor('team', Math.max(camera.distance, 750)), Escape:() => closePops(),
		}[event.code] || (/^Digit[1-9]$/.test(event.code) && ui.bots[Number(event.code.slice(5)) - 1] ? () => camera.followActor(ui.bots[Number(event.code.slice(5)) - 1].current ?? ui.bots[Number(event.code.slice(5)) - 1].id, 650) : null);
		if (handled) { event.preventDefault(); handled(); }
	}, {signal});
	const meter = {frames:0, cpu:0, cpuMax:0, since:performance.now(), samples:[]}, fpsLabel = $('fps');
	function meterTick(now, rendered, cpu) {
		if (rendered) { meter.frames++; meter.cpu += cpu; meter.cpuMax = Math.max(meter.cpuMax, cpu); meter.samples.push(cpu); if (meter.samples.length > 600) meter.samples.splice(0, 300); }
		const span = now - meter.since; if (span < 500) return;
		const fps = meter.frames * 1000 / span, average = meter.frames ? meter.cpu / meter.frames : 0;
		meter.last = {fps, cpu:average, cpuMax:meter.cpuMax, frames:meter.frames};
		if (prefs.fps) { fpsLabel.hidden = false; fpsLabel.textContent = meter.frames ? Math.round(fps) + ' FPS · ' + average.toFixed(1) + ' ms' : '静止 · 0 FPS'; fpsLabel.title = meter.frames ? '实际渲染帧率；ms 为每帧场景与渲染提交的 CPU 时间（最大 ' + meter.cpuMax.toFixed(1) + ' ms）。暂停且画面不变时不渲染。' : '暂停且画面不变时不渲染'; fpsLabel.classList.toggle('slow', meter.frames > 0 && fps < 30); }
		else fpsLabel.hidden = true;
		meter.frames = 0; meter.cpu = 0; meter.cpuMax = 0; meter.since = now;
	}
	function tick(now) {
		if (disposed) return;
		let rendered = false, cpu = 0;
		try {
			const delta = last ? clamp((now - last) / 1000,0,.2) : 0; last = now;
			if (playing && !jump && !pending) {
				const next = desiredTime = clamp(time + delta * speed, 0, manifest.summary.duration);
				if (next < frame.nextTime && next >= frame.sampleTime) { time = next; invalidate(); }
				else if (ahead?.frame && next >= ahead.frame.sampleTime && next < ahead.frame.nextTime) install(ahead.frame, next, false);
				else requestTime();
				if (time >= manifest.summary.duration) {
					if (campaign.index + 1 < campaign.entries.length) seekCampaign(campaign.entries[campaign.index + 1].start);
					else setPlaying(false);
				}
			}
			camera.update(delta);
			if (dirty) { dirty = false; const started = performance.now(); lastStats = scene.render(time); cpu = performance.now() - started; rendered = true; if (scene.ragdolls.pending) invalidate(); }
			else scene.renderer.presentExposure();
		} catch (error) { showError(error); setPlaying(false); }
		try { audio.update(frame, time, playing && !jump && !pending, speed, camera); } catch (error) { console.warn('audio', error); }
		syncPlayButton(); meterTick(now, rendered, cpu);
		animationFrame = requestAnimationFrame(tick);
	}
	try { lastStats = scene.render(time); dirty = !!(scene.ragdolls.pending); } catch (error) { dispose(); throw error; }
	animationFrame = requestAnimationFrame(tick);
	window.__viewer = {ready:true, timing:globalThis.__loadTiming,
		async configure(value) {
			for (const key of [...qualityKeys, 'scale', ...layerKeys, 'trail', 'cut', 'charStyle']) if (value[key] !== undefined) prefs[key] = value[key]; applyQuality(); for (const key of layerKeys) $(key).checked = !!prefs[key];
			if (value.camera) camera.setMode(value.camera); if (value.follow !== undefined && value.follow !== 'free') { camera.followActor(value.follow, value.distance || 650); camera.snap = true; } if (value.follow === 'free') camera.follow = 'free';
			for (const key of ['distance', 'yaw', 'pitch']) if (value[key] !== undefined) camera[key] = value[key]; if (value.drawer !== undefined) setDrawer(value.drawer); if (value.ui !== undefined) document.body.classList.toggle('noui', !value.ui);
			if (value.tab) document.querySelector(`.tabs [data-tab=${value.tab}]`)?.click(); if (value.pop) { const pair = pops.find(([, pop]) => pop === value.pop); if (pair) togglePop(pair[0], pair[1], true); if (value.pop === 'libraryPop') refreshLibrary(); }
			if (value.t !== undefined) await setTime(value.t); if (value.campaignTime !== undefined) await seekCampaign(value.campaignTime); invalidate();
		},
		stats:() => ({...lastStats, bake:renderer.bake, triangles:renderer.triangles, time, campaignTime:campaign.offset + time, campaignDuration:campaign.duration, loadedTime:frame.sampleTime, entities:frame.entities.length}),
		playing:() => playing, setPlaying, seekCampaign, audio, meter:() => meter.last, scene, frameAt:value => recording.seek(value),
		// Average frame rate and per-frame CPU over `ms` of playback at `rate`x (bench helper).
		async measure(ms, rate = 1) { const before = speed, was = playing; setSpeed(rate); meter.samples = []; const start = performance.now(); let frames = 0; const count = () => { frames++; if (performance.now() - start < ms) requestAnimationFrame(count); }; setPlaying(true); await new Promise(resolve => { requestAnimationFrame(count); setTimeout(resolve, ms + 50); }); const samples = meter.samples.slice().sort((a, b) => a - b); setPlaying(was); setSpeed(before); return {fps:frames * 1000 / ms, cpuMean:samples.reduce((a, b) => a + b, 0) / Math.max(1, samples.length), cpuP95:samples[Math.floor(samples.length * .95)] || 0, stats:{...lastStats}}; }
	};
	function dispose() { $('replayBuffer').hidden = true; audio.dispose(); if (hooks.audio === audio) hooks.audio = null; disposed = true; playing = false; shownPlaying = null; syncPlayButton(); fpsLabel.hidden = true; cancelAnimationFrame(animationFrame); listeners.abort(); scene.dispose(); recording.dispose(); hooks.invalidate = () => {}; hooks.layout = () => {}; window.__viewer = null; }
	return dispose;
}
