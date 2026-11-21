'use strict';
// ---- library, game directory and loading ---------------------------------------
let refreshLibrary = () => {};
(async () => {
	const status = text => { $('status').textContent = text; };
	const loading = (on, title) => { $('loading').classList.toggle('idle', !on); if (title) $('loadTitle').textContent = title; if (on) $('loading').classList.remove('gone'); };
	const showWelcome = () => { loading(false, 'L4D2 实机回放'); status('选择一局录像开始回放。地图、人物与道具资源均从本机游戏目录读取。'); };
	const db = await new Promise((resolve, reject) => { const r = indexedDB.open('l4d2-replay-library'); r.onupgradeneeded = () => { r.result.createObjectStore('recent', {keyPath:'id'}); r.result.createObjectStore('settings'); }; r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
	const get = (store, key) => new Promise((resolve, reject) => { const r = db.transaction(store).objectStore(store)[key === undefined ? 'getAllKeys' : 'get'](key); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
	const write = (store, change) => new Promise((resolve, reject) => { const tx = db.transaction(store, 'readwrite'); change(tx.objectStore(store)); tx.oncomplete = resolve; tx.onabort = () => reject(tx.error); });
	const put = (store, value, key) => write(store, s => s.put(value, key));
	const seen = new Set(await get('recent'));
	const savedDirectory = await get('settings', 'gameDirectory');
	let root = savedDirectory?.kind === 'directory' ? savedDirectory : null;
	let service = null, loader = null, disposeReplay = null, pending = null, busy = false, current = null, shown = false;
	let scene = null;
	// Static hosting (publish_web.py):
	// viewer.html?replay=<recording url>, library from index.json (publish_web.py).
	const params = new URLSearchParams(location.search); let staticLibrary = null, storage = {};
	const s3tc = (() => { try { return !!document.createElement('canvas').getContext('webgl2')?.getExtension('WEBGL_compressed_texture_s3tc'); } catch { return false; } })();
	async function api(name, body) { const response = await fetch('api/' + name, body === undefined ? {} : {method:'POST', headers:{'Content-Type':'application/json', 'X-Replay-Viewer':'1'}, body:JSON.stringify(body)}); if (!response.ok) throw Error('本地读取失败：' + response.status); const result = await response.json(); if (result?.error) throw Error(result.error); return result; }
	const serviceRoot = path => ({service:location.origin, path, name:path.split(/[\\/]/).at(-1)});
	function controls(value) {
		busy = value;
		for (const id of ['changeDirectory', 'openRecording', 'gameDirectory', 'welcomeLibrary','chapterSelect']) $(id).disabled = value;
		$('gameDirectory').textContent = root ? (loader ? '游戏目录：' + root.name : '授权并关联：' + root.name) : '关联游戏目录';
		$('gameDirectory').hidden = !!loader && !!service;
		$('gameDir').textContent = root ? (root.path || root.name) : '未关联';
	}
	async function mount(chosen) {
		const next = new ReplayLoader(status);
		try { await next.request('mount', {root:chosen, compressed:s3tc}); } catch (e) { next.dispose(); throw e; }
		if (disposeReplay) {
			disposeReplay(); disposeReplay = null; current = null; shown = false;
			document.body.classList.add('empty');
		}
		if (scene) { scene.renderer.dispose(); scene = null; }
		if (loader) loader.dispose(); loader = next;
		root = chosen;
	}
	let loadQueue = Promise.resolve(), latestLoad = 0;
	function load(file, handle, chapter = 0, start = 0, play = false, speed = 1) {
		const token = ++latestLoad;
		const next = loadQueue.catch(() => {}).then(() => token === latestLoad && loadChapter(file,handle,chapter,start,play,speed,token));
		loadQueue = next;
		return next;
	}
	async function loadChapter(file, handle, chapter, start, play, speed, token) {
		if (!loader) { pending = {file, handle}; loading(false, '需要游戏目录'); status('已选择 ' + file.name + '，请先关联 L4D2 游戏目录。'); return; }
		controls(true); closePops(); loading(true, shown ? '切换录像' : '正在载入'); status('读取 ' + file.name + '…');
		if (disposeReplay) { disposeReplay(); disposeReplay = null; }
		if (scene) { scene.renderer.dispose(); scene = null; }
		shown = false; await new Promise(resolve => requestAnimationFrame(resolve));
		let recording = null;
		try {
			const started = performance.now(), result = await loader.request('load', {source:file.url ? {url:file.url, size:file.size, partSize:file.partSize} : {file, live:file.liveFile || null, liveHandle:file.liveHandle || null, handle:file.liveFile && handle && typeof handle.getFile === 'function' ? handle : null},chapter}); recording = result.recording;
			if (token !== latestLoad) { recording.dispose(); return; }
			const summary = recording.manifest.summary, name = summary.map;
			globalThis.__loadTiming = {load:Math.round(performance.now() - started)};
			const gl = $('world').getContext('webgl2', {antialias:false, alpha:false, depth:false, stencil:false, powerPreference:'high-performance'}); if (!gl) throw Error('浏览器不支持 WebGL 2');
			scene = {G:result.G, models:result.models, renderer:new ReplayRenderer(gl, result.G, result.models)};
			if (!handle.static) {
				const id = handle.path || file.name;
				if (!seen.has(id)) { await put('recent', {id}); seen.add(id); }
			}
			current = file.name;
			status('创建场景…'); await new Promise(resolve => requestAnimationFrame(resolve));
			const sceneStarted = performance.now(), materials = new Set(scene.G.world.map(group => group.material)); let preparedAt = sceneStarted;
			for (const [path, model] of Object.entries(scene.models)) {
				scene.renderer.meshFor(path);
				for (const material of [...model.materials, ...Object.values(model.replacements).flatMap(Object.values)]) materials.add(material);
				if (performance.now() - preparedAt > 8) { await new Promise(resolve => requestAnimationFrame(resolve)); preparedAt = performance.now(); }
			}
			for (const material of materials) {
				for (const key of ['texture', 'second', 'mask', 'emissive', 'gradient', 'lightwarp', 'normal', 'exponent', 'flow', 'lightmap', 'envmap', 'envmapMask']) if (material?.[key]) scene.renderer.texture(material[key]);
				if (performance.now() - preparedAt > 8) { await new Promise(resolve => requestAnimationFrame(resolve)); preparedAt = performance.now(); }
			}
			for (const texture of [...scene.G.cubemaps.map(probe => probe.texture), scene.G.cubemapDefault]) {
				if (texture) scene.renderer.texture(texture);
				if (performance.now() - preparedAt > 8) { await new Promise(resolve => requestAnimationFrame(resolve)); preparedAt = performance.now(); }
			}
			const chapters = result.chapters || [{map:name,duration:summary.duration}];
			let duration = 0;
			const entries = chapters.map(c => { const entry = {...c,start:duration}; duration += c.duration; return entry; });
			const campaign = {entries, index:chapter, offset:entries[chapter].start, duration,
				change:(index,t,playing,rate) => load(file,handle,index,t,playing,rate)};
			disposeReplay = await startReplay(recording, scene.G, scene.models, file, scene.renderer, campaign, start, play, speed); globalThis.__loadTiming.scene = Math.round(performance.now() - sceneStarted);
			const select=$('chapterSelect');select.hidden=!result.chapters;
			select.replaceChildren(...(result.chapters || []).map((c,i)=>new Option((i+1)+'. '+c.map+(result.chapters.some((other,j)=>j!==i && other.map===c.map)?' · '+c.name.replace(/\.l4d2replay$/i,''):''),i)));
			select.value=String(chapter);select.onchange=result.chapters?run(()=>window.__viewer.seekCampaign(entries[Number(select.value)].start)):null;
			const notes = [scene.G.counts.world.toLocaleString() + ' 个地图三角形', scene.G.props.length + ' 个静态道具'];
			$('assetStatus').textContent = notes.join(' · ') + (result.warnings.length ? '。资源提示：' + result.warnings.join('；') : '');
			$('loading').classList.add('gone'); shown = true;
		} catch (e) { if (disposeReplay) { disposeReplay(); disposeReplay = null; } else recording?.dispose(); if (scene) { scene.renderer.dispose(); scene = null; } document.body.classList.add('empty'); loading(false, '载入失败'); throw e; }
		finally { $('loading').classList.add('gone'); controls(false); }
	}
	async function openServiceRecording(path) {
		const handle = await api('recording', path ? {path} : {}); if (!handle) return;
		await load({name:handle.name, url:'api/recording?path=' + encodeURIComponent(handle.path)}, handle);
	}
	async function associate(action) {
		if (busy) return;
		controls(true);
		try {
			let chosen;
			if (service) {
				const result = await api('game-directory', {});
				if (!result) return;
				chosen = serviceRoot(result.gameDirectory);
			} else {
				if (!window.showDirectoryPicker) throw Error('关联游戏目录需要支持目录访问的桌面版 Chrome 或 Edge。');
				chosen = root;
				if (action === 'change' || !root?.requestPermission) {
					chosen = await showDirectoryPicker({id:'l4d2-game', mode:'read', ...(root?.requestPermission ? {startIn:root} : {})});
				}
				if (await chosen.requestPermission({mode:'read'}) !== 'granted') return;
			}
			loading(true, '载入游戏资源'); await mount(chosen);
			if (!service) await put('settings', root, 'gameDirectory');
			if (pending) { const next = pending; pending = null; await load(next.file, next.handle); }
			else showWelcome();
		} catch (e) { if (e.name !== 'AbortError') showError(e); } finally { controls(false); }
	}
	const run = fn => async (...args) => { try { await fn(...args); } catch (e) { if (e.name !== 'AbortError') showError(e); } };
	$('gameDirectory').onclick = () => associate(); $('changeDirectory').onclick = () => associate('change');
	$('welcomeLibrary').onclick = () => togglePop('libraryBtn', 'libraryPop', true) && refreshLibrary();
	$('packRecording').onclick = () => $('packFiles').click();
	$('packFiles').onchange = run(async e => {
		const files=Array.from(e.target.files);e.target.value='';if(!files.length)return;
		$('packRecording').disabled=true;
		try {
			const {blob,name}=await ReplayChunks.pack(files), link=document.createElement('a');
			link.href=URL.createObjectURL(blob);link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(link.href),60000);
		} finally { $('packRecording').disabled=false; }
	});
	$('openRecording').onclick = run(async () => {
		if (service) return openServiceRecording();
		const [handle] = await showOpenFilePicker({id:'l4d2-recording', types:[{description:'L4D2 录像', accept:{'application/octet-stream':['.l4d2replay']}}], multiple:false});
		await openHandle(handle);
	});
	function online(entry) {
		const base = new URL(storage.baseUrl || './',location.href);
		const file = {name:entry.name || entry.replay.split('/').at(-1),url:new URL(entry.replay,base).href,
			size:entry.size,partSize:storage.mode === 'parts' ? storage.partSize : undefined};
		if (file.partSize && (!Number.isSafeInteger(file.size) || file.size < 16)) throw Error('录像索引缺少文件长度');
		return {file,handle:{static:true,path:entry.replay}};
	}
	const size = n => n > 1e6 ? (n / 1e6).toFixed(1) + ' MB' : Math.round(n / 1e3) + ' KB';
	const when = ms => { const d = new Date(ms), now = new Date(), same = d.toDateString() === now.toDateString(); return (same ? '今天 ' : (d.getMonth() + 1) + '月' + d.getDate() + '日 ') + d.toTimeString().slice(0, 5); };
	let library = [], libraryEmpty = '录像目录里还没有 .l4d2replay 文件';
	function renderLibrary() {
		const query = $('libSearch').value.trim().toLowerCase(), list = $('libList'); list.replaceChildren();
		const rows = library.filter(r => !query || r.name.toLowerCase().includes(query));
		for (const r of rows) {
			const el = document.createElement('div'); el.className = 'lib' + (r.name === current ? ' cur' : '');
			const name = document.createElement('b'); name.textContent = r.name.replace(/\.l4d2replay$/, ''); name.title = r.name;
			const meta = document.createElement('span'); meta.className = 'meta'; meta.textContent = r.duration ? fmtTime(r.duration, 0) : r.size != null ? size(r.size) : '';
			const sub = document.createElement('span'); sub.textContent = (r.modified ? when(r.modified) : '') + (seen.has(r.path || r.name) && r.name !== current ? ' · 看过' : '') + (r.name === current ? ' · 正在播放' : '');
			const extra = document.createElement('span'); extra.className = 'meta'; extra.textContent = r.map || '';
			el.append(name, meta, sub, extra); el.onclick = run(() => r.open()); list.append(el);
		}
		if (!rows.length) {
			const empty = document.createElement('div'); empty.className = 'muted'; empty.style.padding = '14px 10px';
			empty.textContent = library.length ? '没有匹配的录像' : libraryEmpty; list.append(empty);
		}
	}
	refreshLibrary = async () => {
		try {
			if (staticLibrary) {
				$('libDir').textContent = '在线回放'; $('pickDirectory').hidden = true; $('openRecording').hidden = true;
				library = staticLibrary.map(r => ({...r,name:r.name || r.replay.split('/').at(-1), open:() => {
					const entry = online(r);
					if (!loader) closePops();
					return load(entry.file,entry.handle);
				}}));
			} else if (service) {
				const result = await api('library'); $('libDir').textContent = result.directory; $('libDir').title = result.directory;
				// <name>.live.l4d2replay is the snapshot of a recording still being written: list the recording as live.
				const live = new Set(result.recordings.filter(r => /\.live\.l4d2replay$/i.test(r.name)).map(r => r.name.replace(/\.live\.l4d2replay$/i, '.l4d2replay')));
				library = result.recordings.filter(r => !/\.live\.l4d2replay$/i.test(r.name)).map(r => ({...r, name:live.has(r.name) ? r.name + '（录制中）' : r.name, modified:r.modified * 1000, open:() => openServiceRecording(r.path)}));
			} else {
				let dir = await get('settings', 'recordingDirectory'), granted = false;
				const rows = [];
				if (dir) {
					try {
						granted = await dir.queryPermission({mode:'read'}) === 'granted';
						if (granted) {
							const handles = new Map();
							for await (const h of dir.values()) if (h.kind === 'file' && /\.l4d2replay$/i.test(h.name)) handles.set(h.name, h);
							for (const [name, handle] of handles) {
								if (/\.live\.l4d2replay$/i.test(name)) continue;
								let file;
								try { file = await handle.getFile(); }
								catch (e) { if (e.name === 'NotFoundError') continue; throw e; }
								const live = handles.get(name.replace(/\.l4d2replay$/i, '.live.l4d2replay'));
								rows.push({name:live ? name + '（录制中）' : name, size:file.size, modified:file.lastModified, open:() => openHandle(handle, live)});
							}
						}
					} catch (e) {
						if (e.name === 'NotFoundError') { dir = null; await write('settings', s => s.delete('recordingDirectory')); }
						else if (e.name !== 'NotAllowedError') throw e;
						granted = false; rows.length = 0;
					}
				}
				library = rows.sort((a, b) => b.modified - a.modified);
				libraryEmpty = !dir ? '请选择存放录像的 record 文件夹。' : !granted ? '请授权读取录像目录。' : '录像目录里还没有 .l4d2replay 文件';
				$('libDir').textContent = dir ? '目录：' + dir.name : '未选择录像目录';
				$('pickDirectory').hidden = false; $('pickDirectory').textContent = granted ? '更换目录…' : dir ? '授权录像目录' : '选择录像目录…';
			}
			renderLibrary();
		} catch (e) { showError(e); }
	};
	async function openHandle(handle, liveHandle) {
		let file, live;
		try {
			if (await handle.queryPermission({mode:'read'}) !== 'granted' && await handle.requestPermission({mode:'read'}) !== 'granted') return;
			// Read the live index first so every chunk it lists is inside the recording snapshot.
			if (liveHandle) {
				try { live = await liveHandle.getFile(); }
				catch (e) { if (e.name !== 'NotFoundError') throw e; }
			}
			file = await handle.getFile();
		} catch (e) {
			if (e.name !== 'NotFoundError') throw e;
			await refreshLibrary(); hint('录像文件已移动或删除，列表已更新。'); return;
		}
		if (live) { file.liveFile = live; file.liveHandle = liveHandle; }
		await load(file, handle);
	}
	$('pickDirectory').onclick = run(async () => {
		let dir = await get('settings', 'recordingDirectory');
		if (dir && $('pickDirectory').textContent === '授权录像目录') {
			try { if (await dir.requestPermission({mode:'read'}) !== 'granted') { $('pickDirectory').textContent = '更换目录…'; return; } }
			catch (e) {
				if (e.name !== 'NotFoundError') throw e;
				await write('settings', s => s.delete('recordingDirectory'));
			}
		}
		else { dir = await showDirectoryPicker({id:'l4d2-recordings', mode:'read'}); await put('settings', dir, 'recordingDirectory'); }
		await refreshLibrary();
	});
	$('libSearch').oninput = renderLibrary;
	$('libSearch').onkeydown = e => { if (e.key === 'Enter') $('libList').querySelector('.lib')?.click(); };
	controls(true);
	if (location.protocol === 'http:' || location.protocol === 'https:') {
		const index = await fetch('index.json').then(r => r.ok ? r.json() : null).catch(() => null);
		if (params.get('replay') || Array.isArray(index?.recordings)) {
			// Static hosting: recordings over HTTP Range; game assets from the visitor's own install.
			staticLibrary = index?.recordings || []; storage = index?.storage || {mode:'range'};
			if (!['parts','range'].includes(storage.mode) || (storage.mode === 'parts' && !(Number.isSafeInteger(storage.partSize) && storage.partSize > 0))) throw Error('在线录像存储配置无效');
			const replay = params.get('replay');
			if (replay) {
				const entry = staticLibrary.find(r => r.replay === replay || r.name === replay);
				pending = entry ? online(entry) : {file:{name:replay.split('/').at(-1),url:new URL(replay,location.href).href},handle:{static:true,path:replay}};
			}
			// Test hook (headless tests only): game files through a same-origin serve.py-style API.
			if (params.has('testGameService')) root = {service:location.origin, path:'', name:'test'};
		} else {
			const r = await fetch('api/session').catch(() => null);
			if (r?.ok) { service = await r.json(); root = service.gameDirectory ? serviceRoot(service.gameDirectory) : null; }
		}
	}
	if (!staticLibrary && !service && (!window.showDirectoryPicker || !window.showOpenFilePicker)) throw Error('请通过 serve.py 打开播放器，或使用桌面版 Edge / Chrome 直接打开 HTML。');
	if (root && (root.service || await root.queryPermission({mode:'read'}) === 'granted')) {
		loading(true, '载入游戏资源'); status('读取游戏目录…');
		try { await mount(root); } finally { controls(false); }
		const open = params.get('open');
		if (pending) { const next = pending; pending = null; await run(load)(next.file, next.handle); }
		else if (open && service) await run(openServiceRecording)(open);
		else showWelcome();
	} else { controls(false); loading(false, 'L4D2 实机回放'); status(root ? '已记住游戏目录，点击“授权并关联”恢复访问。' : '先关联游戏目录，再打开 .l4d2replay 录像。资源仅在本机读取。'); }
})().catch(showError);

