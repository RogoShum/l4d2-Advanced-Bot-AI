'use strict';
// ---- library, game directory and loading ---------------------------------------
let refreshLibrary = () => {};
(async () => {
	const status = text => { $('status').textContent = text; };
	const loading = (on, title) => { $('loading').classList.toggle('idle', !on); if (title) $('loadTitle').textContent = title; if (on) $('loading').classList.remove('gone'); };
	const db = await new Promise((resolve, reject) => { const r = indexedDB.open('l4d2-replay-library'); r.onupgradeneeded = () => { r.result.createObjectStore('recent', {keyPath:'id'}); r.result.createObjectStore('settings'); }; r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
	const get = (store, key) => new Promise((resolve, reject) => { const r = db.transaction(store).objectStore(store)[key === undefined ? 'getAll' : 'get'](key); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
	const put = (store, value, key) => new Promise((resolve, reject) => { const tx = db.transaction(store, 'readwrite'); tx.objectStore(store).put(value, key); tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); });
	let recent = await get('recent'), root = await get('settings', 'gameDirectory'), recordingLocation = await get('settings', 'recordingLocation');
	let service = null, loader = null, disposeReplay = null, pending = null, busy = false, current = null, shown = false;
	let scene = null;
	// Static hosting (export_web.py output on any Range-capable static server):
	// viewer.html?replay=<recording url>, library from index.json (publish_web.py).
	const params = new URLSearchParams(location.search); let staticLibrary = null, storage = {};
	const s3tc = (() => { try { return !!document.createElement('canvas').getContext('webgl2')?.getExtension('WEBGL_compressed_texture_s3tc'); } catch { return false; } })();
	async function api(name, body) { const response = await fetch('api/' + name, body === undefined ? {} : {method:'POST', headers:{'Content-Type':'application/json', 'X-Replay-Viewer':'1'}, body:JSON.stringify(body)}); if (!response.ok) throw Error('本地读取失败：' + response.status); const result = await response.json(); if (result?.error) throw Error(result.error); return result; }
	const serviceRoot = path => ({service:location.origin, path, name:path.split(/[\\/]/).at(-1)});
	function controls(value) {
		busy = value;
		for (const id of ['changeDirectory', 'openRecording', 'gameDirectory', 'welcomeLibrary','chapterSelect']) $(id).disabled = value;
		$('gameDirectory').textContent = root ? (loader ? '游戏目录：' + root.name : '授权并关联：' + root.name) : '关联游戏目录';
		$('gameDirectory').hidden = !!loader && (!!service || !!staticLibrary);
		$('gameDir').textContent = root ? (root.path || root.name) : '未关联';
	}
	async function mount(chosen) {
		const next = new ReplayLoader(status);
		try { await next.request('mount', {root:chosen, compressed:s3tc}); } catch (e) { next.dispose(); throw e; }
		if (disposeReplay) { disposeReplay(); disposeReplay = null; }
		if (scene) { scene.renderer.dispose(); scene = null; }
		if (loader) loader.dispose(); loader = next; root = chosen;
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
			const started = performance.now(), result = await loader.request('load', {source:file.url ? {url:file.url, size:file.size, partSize:file.partSize, durations:file.durations} : {file, durations:file.durations, live:file.liveFile || null, liveHandle:file.liveHandle || null, handle:file.liveFile && handle && typeof handle.getFile === 'function' ? handle : null},chapter}); recording = result.recording;
			if (token !== latestLoad) { recording.dispose(); return; }
			const summary = recording.manifest.summary, name = summary.map;
			globalThis.__loadTiming = {load:Math.round(performance.now() - started)};
			const gl = $('world').getContext('webgl2', {antialias:false, alpha:false, depth:false, stencil:false, powerPreference:'high-performance'}); if (!gl) throw Error('浏览器不支持 WebGL 2');
			scene = {G:result.G, models:result.models, renderer:new ReplayRenderer(gl, result.G, result.models)};
			const id = handle.path || file.name, entry = {id, name:file.name, map:name, duration:summary.duration, openedAt:Date.now(), handle}; if (!handle.static) { await put('recent', entry); recent = recent.filter(r => r.id !== id); recent.push(entry); } current = file.name;
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
			file.durations = chapters.map(c => c.duration);
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
	async function openRecent(entry) {
		if (entry.handle.service) return openServiceRecording(entry.handle.path);
		if (await entry.handle.queryPermission({mode:'read'}) !== 'granted' && await entry.handle.requestPermission({mode:'read'}) !== 'granted') return;
		recordingLocation = entry.handle; await put('settings', recordingLocation, 'recordingLocation'); await load(await entry.handle.getFile(), entry.handle);
	}
	async function associate(change) {
		if (busy) return;
		try {
			let chosen;
			if (service) { controls(true); const result = await api('game-directory', {}); if (!result) return; chosen = serviceRoot(result.gameDirectory); }
			else if (!window.showDirectoryPicker) chosen = await pickFolderFiles();
			else { chosen = change || !root?.requestPermission ? await showDirectoryPicker({id:'l4d2-game', mode:'read', ...(root?.requestPermission ? {startIn:root} : {})}) : root; if (await chosen.requestPermission({mode:'read'}) !== 'granted') return; }
			if (!chosen) return;
			controls(true); loading(true, '载入游戏资源'); await mount(chosen); if (!chosen.files) await put('settings', root, 'gameDirectory');
			if (pending) { const next = pending; pending = null; await load(next.file, next.handle); }
			else if (!shown) { loading(false, 'L4D2 实机回放'); status('游戏目录已关联。打开录像库选择一局录像。'); }
		} catch (e) { if (e.name !== 'AbortError') showError(e); } finally { controls(false); }
	}
	// Browsers without showDirectoryPicker (Firefox, Safari): <input webkitdirectory>. The browser
	// lists the folder's files; only the ones the replay needs are read, locally. Not remembered.
	function pickFolderFiles() {
		return new Promise(resolve => {
			const input = document.createElement('input'); input.type = 'file'; input.webkitdirectory = true; input.multiple = true;
			input.onchange = () => { const files = [...input.files]; if (!files.length) return resolve(null); const name = files[0].webkitRelativePath.split('/')[0]; resolve({name, files:files.map(file => ({path:file.webkitRelativePath.split('/').slice(1).join('/'), file}))}); };
			input.oncancel = () => resolve(null); input.click();
		});
	}
	const gameFolderHelp = '请选择本机的 Left 4 Dead 2 游戏目录（包含 left4dead2 文件夹的那一层，例如 Steam\steamapps\common\Left 4 Dead 2）。地图、人物与材质只在你的浏览器里读取，不会上传。';
	const run = fn => async (...args) => { try { await fn(...args); } catch (e) { if (e.name !== 'AbortError') showError(e); } };
	$('gameDirectory').onclick = () => associate(false); $('changeDirectory').onclick = () => associate(true);
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
		const [handle] = await showOpenFilePicker({id:'l4d2-recording', ...(recordingLocation ? {startIn:recordingLocation} : {}), types:[{description:'L4D2 录像', accept:{'application/octet-stream':['.l4d2replay']}}], multiple:false});
		recordingLocation = handle; await put('settings', recordingLocation, 'recordingLocation'); await load(await handle.getFile(), handle);
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
	let library = [];
	function renderLibrary() {
		const query = $('libSearch').value.trim().toLowerCase(), list = $('libList'), seen = new Set(recent.map(r => r.name)); list.replaceChildren();
		const rows = library.filter(r => !query || r.name.toLowerCase().includes(query));
		for (const r of rows) {
			const el = document.createElement('div'); el.className = 'lib' + (r.name === current ? ' cur' : '');
			const name = document.createElement('b'); name.textContent = r.name.replace(/\.l4d2replay$/, ''); name.title = r.name;
			const meta = document.createElement('span'); meta.className = 'meta'; meta.textContent = r.duration ? fmtTime(r.duration, 0) : size(r.size);
			const sub = document.createElement('span'); sub.textContent = (r.modified ? when(r.modified) : '') + (seen.has(r.name) && r.name !== current ? ' · 看过' : '') + (r.name === current ? ' · 正在播放' : '');
			const extra = document.createElement('span'); extra.className = 'meta'; extra.textContent = r.map || '';
			el.append(name, meta, sub, extra); el.onclick = run(() => r.open()); list.append(el);
		}
		if (!rows.length) { const empty = document.createElement('div'); empty.className = 'muted'; empty.style.padding = '14px 10px'; empty.textContent = library.length ? '没有匹配的录像' : '录像目录里还没有 .l4d2replay 文件'; list.append(empty); }
	}
	refreshLibrary = async () => {
		try {
			if (staticLibrary) {
				$('libDir').textContent = '在线回放'; $('pickDirectory').hidden = true; $('openRecording').hidden = true;
				library = staticLibrary.map(r => ({...r,name:r.name || r.replay.split('/').at(-1), open:() => {
					const entry = online(r);
					if (!loader) { pending = entry; closePops(); status('已选择 ' + entry.file.name + '。' + gameFolderHelp); return; }
					return load(entry.file,entry.handle);
				}}));
			} else if (service) {
				const result = await api('library'); $('libDir').textContent = result.directory; $('libDir').title = result.directory;
				// <name>.live.l4d2replay is the snapshot of a recording still being written: list the recording as live.
				const live = new Set(result.recordings.filter(r => /\.live\.l4d2replay$/i.test(r.name)).map(r => r.name.replace(/\.live\.l4d2replay$/i, '.l4d2replay')));
				library = result.recordings.filter(r => !/\.live\.l4d2replay$/i.test(r.name)).map(r => ({...r, name:live.has(r.name) ? r.name + '（录制中）' : r.name, modified:r.modified * 1000, open:() => openServiceRecording(r.path)}));
			} else {
				// Opened as a local file: list a chosen recordings folder (File System Access), plus recent files.
				const dir = await get('settings', 'recordingDirectory'), granted = dir && await dir.queryPermission({mode:'read'}) === 'granted', rows = [];
				// <name>.live.l4d2replay is the snapshot index of a recording still being written: not listed itself;
				// the recording is listed as live and opened together with it.
				const handles = [];
				if (granted) for await (const handle of dir.values()) if (handle.kind === 'file' && /\.l4d2replay$/i.test(handle.name)) handles.push(handle);
				const liveHandles = new Map(handles.filter(h => /\.live\.l4d2replay$/i.test(h.name)).map(h => [h.name.replace(/\.live\.l4d2replay$/i, '.l4d2replay'), h]));
				for (const handle of handles) if (!/\.live\.l4d2replay$/i.test(handle.name)) { const f = await handle.getFile(), live = liveHandles.get(handle.name); rows.push({name:live ? handle.name + '（录制中）' : handle.name, size:f.size, modified:f.lastModified, open:() => openHandle(handle, live)}); }
				for (const r of recent) if (!rows.some(x => x.name === r.name)) rows.push({name:r.name, duration:r.duration, map:r.map, modified:r.openedAt, open:() => openRecent(r)});
				rows.sort((a, b) => b.modified - a.modified); library = rows;
				$('libDir').textContent = granted ? '目录：' + dir.name : dir ? '录像目录需要重新授权' : '最近打开（可选择录像目录）';
				$('pickDirectory').hidden = false; $('pickDirectory').textContent = granted ? '更换目录…' : dir ? '授权录像目录' : '选择录像目录…';
			}
			renderLibrary();
		} catch (e) { showError(e); }
	};
	async function openHandle(handle, liveHandle) {
		recordingLocation = handle; await put('settings', handle, 'recordingLocation');
		// The live index first, then the recording: every chunk it lists is then inside the file snapshot.
		const live = liveHandle ? await liveHandle.getFile() : null, file = await handle.getFile(); if (live) { file.liveFile = live; file.liveHandle = liveHandle; }
		await load(file, handle);
	}
	$('pickDirectory').onclick = run(async () => {
		let dir = await get('settings', 'recordingDirectory');
		if (dir && await dir.queryPermission({mode:'read'}) !== 'granted' && $('pickDirectory').textContent === '授权录像目录') { if (await dir.requestPermission({mode:'read'}) !== 'granted') return; }
		else { dir = await showDirectoryPicker({id:'l4d2-recordings', mode:'read', ...(recordingLocation ? {startIn:recordingLocation} : {})}); await put('settings', dir, 'recordingDirectory'); }
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
			if (root?.service && params.has('testGameService') || root?.queryPermission && await root.queryPermission({mode:'read'}) === 'granted') {
				loading(true, '载入游戏资源'); status('读取本机游戏目录…');
				try { await mount(root); } finally { controls(false); }
				if (pending) { const next = pending; pending = null; await run(load)(next.file, next.handle); } else { loading(false, 'L4D2 实机回放'); status('打开录像库选择一局录像。'); }
			} else { controls(false); loading(false, root ? '需要重新授权游戏目录' : '需要本机游戏目录'); status((root ? '已记住游戏目录，点击“授权并关联”恢复访问。' : '') + gameFolderHelp); }
			return;
		}
	}
	if (location.protocol === 'http:' || location.protocol === 'https:') { const r = await fetch('api/session').catch(() => null); if (r?.ok) { service = await r.json(); root = service.gameDirectory ? serviceRoot(service.gameDirectory) : null; } }
	if (!service && (!window.showDirectoryPicker || !window.showOpenFilePicker)) throw Error('请通过 serve.py 打开播放器，或使用桌面版 Edge / Chrome 直接打开 HTML。');
	if (root && (service || await root.queryPermission({mode:'read'}) === 'granted')) {
		loading(true, '载入游戏资源'); status('读取游戏目录…');
		try { await mount(root); } finally { controls(false); }
		const open = new URLSearchParams(location.search).get('open');
		if (open && service) await run(openServiceRecording)(open);
		else { loading(false, 'L4D2 实机回放'); status('选择一局录像开始回放。地图、人物与道具资源均从本机游戏目录读取。'); }
	} else { controls(false); loading(false, 'L4D2 实机回放'); status(root ? '已记住游戏目录，点击“授权并关联”恢复访问。' : '先关联游戏目录，再打开 .l4d2replay 录像。资源仅在本机读取。'); }
})().catch(showError);

