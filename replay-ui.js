'use strict';
// Shared viewer controls and per-recording interface.
const $ = id => document.getElementById(id);
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const fmtTime = (s, digits = 1) => { s = Math.max(0, s); const m = Math.floor(s / 60), r = s - m * 60; return m + ':' + (r < 10 ? '0' : '') + r.toFixed(digits); };
const PREFS_KEY = 'l4d2-replay-viewer';
const PRESETS = {
	high:{shadows:true, softShadows:false, outline:true, ao:true, bloom:true, fxaa:true, glass:true, scale:1},
	medium:{shadows:true, softShadows:false, outline:true, ao:false, bloom:true, fxaa:true, glass:true, scale:.8},
	low:{shadows:false, softShadows:false, outline:true, ao:false, bloom:false, fxaa:false, glass:false, scale:.67},
};
const defaults = {firstFov:60, isometric:false, charStyle:'real', preset:'high', ...PRESETS.high, xray:true, labels:true, trail:'8', nav:false, hitbox:false, slice:true, fps:true, botai:true, cut:120, drawer:true, mini:true, mapLighting:true, timeOfDay:12, fog:'map', audio:false, audioVolume:.7, audioSurvivor:true, audioSpecial:true, audioCommon:true, audioMusic:true, audioSpeed:'2x'};
const savedPrefs = JSON.parse(localStorage.getItem(PREFS_KEY) || '{}');
const prefs = Object.fromEntries(Object.entries(defaults).map(([key, value]) => [key, savedPrefs[key] ?? value]));
const savePrefs = () => localStorage.setItem(PREFS_KEY, JSON.stringify(prefs));
const hooks = {invalidate() {}, layout() {}, audio:null};
$('firstFov').value = $('fovLabel').value = prefs.firstFov;
$('firstFov').oninput = e => { prefs.firstFov = +e.target.value; $('fovLabel').value = prefs.firstFov; savePrefs(); hooks.invalidate(); };
$('isometric').checked = prefs.isometric;
$('isometric').onchange = e => { prefs.isometric = e.target.checked; savePrefs(); hooks.invalidate(); };
// Sound settings. Audio starts only from a click (browser autoplay rules).
$('audioOn').checked = prefs.audio; $('audioVolume').value = prefs.audioVolume; $('audioSpeed').value = prefs.audioSpeed;
for (const [id, key] of [['audioSurvivor', 'audioSurvivor'], ['audioSpecial', 'audioSpecial'], ['audioCommon', 'audioCommon'], ['audioMusic', 'audioMusic']]) { $(id).checked = prefs[key] !== false; $(id).onchange = e => { prefs[key] = e.target.checked; savePrefs(); if (key === 'audioMusic' && !prefs[key]) hooks.audio?.stopMusic(.3); }; }
$('audioOn').onchange = e => { prefs.audio = e.target.checked; savePrefs(); if (prefs.audio) hooks.audio?.enable(); else hooks.audio?.stopAll(); };
$('audioVolume').oninput = e => { prefs.audioVolume = Number(e.target.value); savePrefs(); };
$('audioSpeed').onchange = e => { prefs.audioSpeed = e.target.value; savePrefs(); };
document.addEventListener('pointerdown', () => { if (prefs.audio) hooks.audio?.enable(); });
$('mapLighting').checked = prefs.mapLighting; $('fogMode').value = prefs.fog; $('fogMode').onchange = e => { prefs.fog = e.target.value; savePrefs(); hooks.invalidate(); }; $('timeOfDay').value = prefs.timeOfDay;
function atmosphere() { $('timeOfDay').disabled = prefs.mapLighting; const minutes = Math.round(prefs.timeOfDay * 60) % 1440; $('timeOfDayLabel').textContent = String(Math.floor(minutes / 60)).padStart(2,'0') + ':' + String(minutes % 60).padStart(2,'0'); savePrefs(); hooks.invalidate(); }
$('mapLighting').onchange = e => { prefs.mapLighting = e.target.checked; atmosphere(); };
$('timeOfDay').oninput = e => { prefs.timeOfDay = Number(e.target.value); atmosphere(); }; atmosphere();

function showError(e) { console.error(e); $('error').textContent = e?.stack && !(e instanceof Error && e.message.length < 200 && !/at /.test(e.stack)) ? e.message + '\n' + e.stack.split('\n').slice(1, 4).join('\n') : (e?.message || String(e)); }
$('error').onclick = () => $('error').textContent = '';
// Mouse-clicked buttons keep no focus, so Space always means play/pause.
document.addEventListener('pointerup', e => { const b = e.target.closest?.('button'); if (b) setTimeout(() => b.blur()); });
function hint(text, ms = 2600) { const el = $('hint'); el.textContent = text; el.classList.remove('gone'); clearTimeout(hint.timer); hint.timer = setTimeout(() => el.classList.add('gone'), ms); }

// ---- popovers ---------------------------------------------------------------
const pops = [['layersBtn', 'layersPop'], ['settingsBtn', 'settingsPop'], ['generalBtn', 'generalPop'], ['libraryBtn', 'libraryPop'], ['helpBtn', 'helpPop']];
function closePops(except) { for (const [b, p] of pops) if (p !== except) { $(p).classList.remove('open'); $(b).classList.remove('on'); } }
function togglePop(button, pop, force) {
	const el = $(pop), open = force ?? !el.classList.contains('open'); closePops(pop);
	el.classList.toggle('open', open); $(button).classList.toggle('on', open);
	if (open) { const r = $(button).getBoundingClientRect(), w = el.offsetWidth; el.style.left = clamp(r.right - w, 14, innerWidth - w - 14) + 'px'; el.style.top = (r.bottom + 10) + 'px'; }
	return open;
}
for (const [button, pop] of pops) $(button).onclick = () => { if (togglePop(button, pop) && pop === 'libraryPop') refreshLibrary(); };
document.addEventListener('pointerdown', e => { if (!e.target.closest('.pop') && !pops.some(([b]) => e.target.closest('#' + b))) closePops(); });

// ---- settings controls --------------------------------------------------------
const qualityKeys = ['shadows', 'softShadows', 'outline', 'ao', 'bloom', 'fxaa', 'glass'];
function applyQuality() {
	for (const k of qualityKeys) $('q_' + k).checked = !!prefs[k];
	$('q_scale').value = String(prefs.scale);
	for (const b of document.querySelectorAll('#presets .btn')) b.classList.toggle('on', b.dataset.preset === prefs.preset);
	for (const b of document.querySelectorAll('#charStyle .btn')) b.classList.toggle('on', b.dataset.style === prefs.charStyle);
	// Ink outlines belong to the cartoon style only; realistic draws none.
	$('q_outline').disabled = prefs.charStyle === 'real'; $('q_outline').closest('.row').classList.toggle('off', prefs.charStyle === 'real'); $('q_outline').closest('.row').title = prefs.charStyle === 'real' ? '写实风格不描边；切换到卡通后生效' : '';
	document.body.classList.toggle('lite', !prefs.glass); hooks.invalidate(); hooks.layout();
}
for (const k of qualityKeys) $('q_' + k).onchange = e => { prefs[k] = e.target.checked; prefs.preset = 'custom'; savePrefs(); applyQuality(); };
$('q_scale').onchange = e => { prefs.scale = Number(e.target.value); prefs.preset = 'custom'; savePrefs(); applyQuality(); };
for (const b of document.querySelectorAll('#charStyle .btn')) b.onclick = () => { prefs.charStyle = b.dataset.style; savePrefs(); applyQuality(); };
for (const b of document.querySelectorAll('#presets .btn')) b.onclick = () => { Object.assign(prefs, PRESETS[b.dataset.preset], {preset:b.dataset.preset}); savePrefs(); applyQuality(); };
const layerKeys = ['xray', 'labels', 'nav', 'hitbox', 'slice', 'fps', 'botai'];
for (const k of layerKeys) { $(k).checked = !!prefs[k]; $(k).onchange = e => { prefs[k] = e.target.checked; savePrefs(); hooks.invalidate(); }; }
$('trail').value = String(prefs.trail); $('trail').onchange = e => { prefs.trail = e.target.value; savePrefs(); hooks.invalidate(); };
$('cut').value = String(prefs.cut); $('cut').oninput = e => { prefs.cut = Number(e.target.value); savePrefs(); hooks.invalidate(); };
function setDrawer(open) { prefs.drawer = open; savePrefs(); $('drawer').classList.toggle('closed', !open); $('drawerBtn').classList.toggle('on', open); }
function setMini(open) { prefs.mini = open; savePrefs(); $('miniWrap').classList.toggle('hidden', !open); $('miniBtn').classList.toggle('on', open); hooks.invalidate(); }
$('drawerBtn').onclick = () => setDrawer(!prefs.drawer); $('miniBtn').onclick = () => setMini(!prefs.mini);
setDrawer(prefs.drawer); setMini(prefs.mini); applyQuality();
for (const b of document.querySelectorAll('.tabs .btn')) b.onclick = () => { for (const o of document.querySelectorAll('.tabs .btn')) o.classList.toggle('on', o === b); $('drawer').classList.toggle('ov', b.dataset.tab === 'overview'); $('drawer').classList.toggle('bt', b.dataset.tab === 'botai'); hooks.invalidate(); };

// Downed (incapacitated) state: a hue none of the four survivor colours use, always paired
// with a pattern (hatching / dashes / diamond) so it does not rely on colour alone.
const DOWNED = '#ff2e7e';
const replayTypes = {infected:['普感', '#dc7979'], smoker:['Smoker', '#b2ce58'], boomer:['Boomer', '#d5b14d'], hunter:['Hunter', '#8e91f3'], spitter:['Spitter', '#9fec57'], jockey:['Jockey', '#f2935b'], charger:['Charger', '#d071d4'], tank:['Tank', '#ff445d'], witch:['Witch', '#fff0a0'], tank_rock:['石头', '#b9bec7'], insect_swarm:['酸液', '#a2d849'], inferno:['火焰', '#ff9a32'], spitter_projectile:['酸液弹', '#c6ef47'], pipe_bomb_projectile:['土制炸弹', '#ffffff'], molotov_projectile:['燃烧瓶', '#ffc170'], vomitjar_projectile:['胆汁', '#bfff79'], survivor_npc:['剧情生还者', '#a8cad8']};
const specialTypes = ['smoker', 'boomer', 'hunter', 'spitter', 'jockey', 'charger'];
const weaponNames = {pistol:'手枪', pistol_magnum:'马格南', smg:'UZI', smg_silenced:'消音冲锋枪', smg_mp5:'MP5', pumpshotgun:'木喷', shotgun_chrome:'铁喷', autoshotgun:'连喷', shotgun_spas:'SPAS', rifle:'M16', rifle_ak47:'AK-47', rifle_desert:'SCAR', rifle_sg552:'SG552', rifle_m60:'M60', hunting_rifle:'猎枪', sniper_military:'军狙', sniper_awp:'AWP', sniper_scout:'鸟狙', grenade_launcher:'榴弹', chainsaw:'电锯', melee:'近战', first_aid_kit:'医疗包', pain_pills:'止痛药', adrenaline:'肾上腺素', defibrillator:'电击器', pipe_bomb:'土制', molotov:'燃烧瓶', vomitjar:'胆汁', gascan:'油桶', propanetank:'丙烷罐', oxygentank:'氧气瓶', fireworkcrate:'烟花箱', cola_bottles:'可乐', gnome:'侏儒'};
const actorType = entity => entity.team === 2 ? 'survivor' : entity.zombie ? ['', 'smoker', 'boomer', 'hunter', 'spitter', 'jockey', 'charger', 'witch', 'tank'][entity.zombie] || entity.classname : entity.classname;
const actorColor = (entity, meta) => meta?.color || replayTypes[actorType(entity)]?.[1] || '#a8cad8';
const replayRgb = hex => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255);
const replayNode = (tag, cls, text) => { const node = document.createElement(tag); if (cls) node.className = cls; if (text !== undefined) node.textContent = text; return node; };
const replayChip = (text, cls = '') => replayNode('span', 'chip ' + cls, text);
function replayAt(rows, time) { let lo = 0, hi = rows.length; while (lo < hi) { const mid = (lo + hi) >> 1; if (rows[mid][0] <= time) lo = mid + 1; else hi = mid; } return lo - 1; }
function replayFirst(rows, time) { let lo = 0, hi = rows.length; while (lo < hi) { const mid = (lo + hi) >> 1; if (rows[mid].t < time) lo = mid + 1; else hi = mid; } return lo; }
function actorStatus(entity) { return entity.life === 3 ? '倒地' : entity.life === 1 || entity.life === 2 ? '死亡' : entity.status?.ledge ? '吊边' : entity.status?.attacker ? '受控' : entity.use?.action ? '交互' : '站立'; }

globalThis.ReplayUI = class {
	constructor(manifest, actions, signal, hudIcons) {
		this.manifest = manifest; this.actions = actions; this.campaign = actions.campaign; this.hudIcons = hudIcons; this.bots = ReplayUI.survivorSlots(manifest); this.actorById = new Map(manifest.entities.map(a => [a.id, a])); for (const bot of this.bots) for (const member of bot.members) this.actorById.set(member.id, {...member, type:'survivor', color:bot.color}); this.time = 0;
		const tankSpawns = new Set(manifest.events.filter(event => event.name === 'tank_spawn' && event.actor !== undefined).map(event => event.actor + ':' + event.t));
		this.cards = new Map(); this.events = manifest.events.filter(event => event.cat && !(event.name === 'player_spawn' && event.type === 'tank' && tankSpawns.has(event.actor + ':' + event.t))); this.visibleEvents = []; this.eventStart = -1;
		const survivor = a => a?.type === 'survivor' || a?.classname === 'survivor_npc' || a?.classname === 'player' && a.team === 4 && a.zombie === 9;
		const special = a => a && (specialTypes.includes(a.type) || a.type === 'tank' || a.type === 'witch');
		this.notices = [];
		for (const e of manifest.events) {
			const down = e.name === 'player_incapacitated'; if (!down && e.name !== 'player_death') continue;
			const source = this.actorById.get(e.attacker_actor), target = this.actorById.get(e.actor);
			if (special(source) && survivor(target) || !down && survivor(source) && special(target)) this.notices.push([e.t, source, target, down, (e.weapon || '').replace(/^weapon_/, '')]);
		}
		this.notices.sort((a,b) => a[0]-b[0]);
		this.categories = {hurt:['受伤', true], incap:['倒地', true], special:['特感', true], boss:['Tank / Witch', true], pour:['灌油', true], bleed:['倒地流血', false]};
		this.filter = {cats:Object.fromEntries(Object.entries(this.categories).map(([key, value]) => [key, value[1]])), bots:new Set(this.bots.flatMap(a => a.members.map(m => m.userid)))};
		this.createHeader(); this.createOverview(); this.createCards(); this.buildFilters(); this.filterEvents(); this.bindTimeline(signal);
		$('events').addEventListener('scroll', () => this.renderEvents(), {signal, passive:true});
		$('damagePrev').onclick = () => this.stepEvent(-1); $('damageNext').onclick = () => this.stepEvent(1);
	}
	// Survivor slots: entities that are the same survivor across a takeover share one slot. Recorded
	// bot_player_replace (a player took a bot over) / player_bot_replace (a bot took over from a player) link
	// them; older recordings link the same survivor model ending and reappearing within 3 s.
	static survivorSlots(manifest) {
		const survivors = manifest.entities.filter(a => a.team === 2).sort((a, b) => a.start - b.start), parent = new Map(survivors.map(a => [a.id, a.id]));
		const find = id => { while (parent.get(id) !== id) id = parent.get(id); return id; }, join = (a, b) => { const ra = find(a), rb = find(b); if (ra !== rb) parent.set(rb, ra); };
		const byUser = new Map(survivors.map(a => [a.userid, a]));
		for (const event of manifest.events) if ((event.name === 'bot_player_replace' || event.name === 'player_bot_replace') && byUser.has(event.player) && byUser.has(event.bot)) join(byUser.get(event.bot).id, byUser.get(event.player).id);
		for (const b of survivors) for (const a of survivors) if (a !== b && a.model === b.model && a.end <= b.start + 3 && b.start - a.end <= 3) join(a.id, b.id);
		const groups = new Map(); for (const a of survivors) { const root = find(a.id); if (!groups.has(root)) groups.set(root, []); groups.get(root).push(a); }
		return [...groups.values()].map((members, index) => ({...members[0], name:[...new Set(members.map(m => m.name))].join(' / '), members, type:'survivor', color:['#65c6ff', '#ffb66b', '#a88cff', '#5ee3a1'][index % 4]}));
	}
	createHeader() {
		const summary = this.manifest.summary, end = {map_transition:['已过关', 'good'], round_end:['回合结束', 'bad'], recording_window:['观察片段', '']}[summary.end] || [summary.end, ''];
		$('title').textContent = summary.map; document.title = summary.map + ' · L4D2 回放';
		$('chips').replaceChildren(replayChip(end[0], end[1]), replayChip(summary.difficulty), replayChip(summary.tickrate + ' tick'), replayChip('skill ' + summary.skill), replayChip(fmtTime(summary.duration, 0)));
	}
	createOverview() {
		const summary = this.manifest.summary, el = $('overview'); el.replaceChildren();
		const heading = text => el.append(replayNode('h4', '', text)), stats = replayNode('div', 'stats'), stat = (value, label) => { const cell = replayNode('div', 'stat'); cell.append(replayNode('b', '', value), replayNode('span', '', label)); stats.append(cell); };
		heading('本局'); stat(fmtTime(summary.duration, 0), '时长'); stat(summary.hurt_events, '受伤次数'); stat(summary.incap_events, '倒地');
		const goal = this.manifest.timeline.objective.at(-1); stat(goal && goal[2] > 0 ? goal[1] + '/' + goal[2] : '—', '灌油'); stat(specialTypes.reduce((n, k) => n + (summary.observed_types[k] || 0), 0), '特感'); stat(summary.observed_types.tank || 0, 'Tank'); el.append(stats);
		heading('生还者'); const table = replayNode('div', 'botsum'); table.append(replayNode('span'), replayNode('span', 'muted', '名字'), replayNode('span', 'muted', '受伤'), replayNode('span', 'muted', '倒地'));
		for (const bot of this.bots) { const info = summary.bots.find(a => bot.members.some(m => a.userid === m.userid) || a.name === bot.name), dot = replayNode('span', 'dot'); dot.style.setProperty('--c', bot.color); table.append(dot, replayNode('span', '', bot.name), replayNode('span', '', (info?.logged_damage_amount ?? '—') + ' HP'), replayNode('span', '', info?.incaps ?? '—')); } el.append(table);
		const causes = Object.entries(summary.damage_by_cause).sort((a, b) => b[1] - a[1]);
		if (causes.length) { heading('受伤来源（事件次数）'); const bars = replayNode('div', 'bars'); for (const [name, count] of causes) { const row = replayNode('div', 'barrow'), track = replayNode('div', 'track'), fill = replayNode('div', 'fill'); fill.style.width = Math.max(2, count / causes[0][1] * 100) + '%'; track.append(fill); row.append(replayNode('span', 'lab', name), track, replayNode('span', 'v', count)); bars.append(row); } el.append(bars); }
		heading('本局出现'); const types = replayNode('div', 'types'); for (const [type, count] of Object.entries(summary.observed_types)) { const chip = replayChip((replayTypes[type]?.[0] || type) + ' ' + count), dot = replayNode('i', 'dot'); dot.style.setProperty('--c', replayTypes[type]?.[1] || '#a8cad8'); chip.prepend(dot); types.append(chip); } el.append(types);
		heading('数据说明'); el.append(replayNode('p', 'note', '位置、血量、装备与技能状态来自服务器录制。人物动作按原生动画序列、姿态参数和叠加层重建；枪口火光与弹道对应实际开火和命中事件。'));
	}
	createCards() {
		$('squad').replaceChildren();
		this.bots.forEach((bot, index) => {
			const card = replayNode('div', 'bot glass'); card.style.setProperty('--c', bot.color);
			card.innerHTML = `<div class="bot-top"><span class="key">${index + 1}</span><b></b><span class="state"></span><span class="hp"></span></div><div class="hpbar"><i class="perm"></i><i class="temp"></i></div><div class="inventory"></div><div class="pour" hidden><i></i></div>`;
			card.querySelector('b').textContent = bot.name; card.onclick = () => { const id = bot.current ?? bot.id; this.actions.follow(this.actions.camera.follow === id ? 'team' : id, 650); };
			const slots = []; for (let slot = 0; slot < 6; slot++) { const cell = replayNode('div', 'inventory-slot empty'), icon = replayNode('canvas', 'item-icon'), name = replayNode('span', 'item-name', '—'), ammo = replayNode('span', 'item-ammo'), clip = replayNode('span'), reserve = replayNode('span'); icon.hidden = true; ammo.hidden = true; ammo.append(clip, reserve); cell.append(icon, name, ammo); cell.hidden = slot === 5; card.querySelector('.inventory').append(cell); slots.push({cell, icon, name, ammo, clip, reserve}); }
			this.cards.set(bot.id, {card, slots, name:card.querySelector('b'), state:card.querySelector('.state'), hp:card.querySelector('.hp'), bar:card.querySelector('.hpbar'), perm:card.querySelector('.perm'), temp:card.querySelector('.temp'), pour:card.querySelector('.pour'), pourFill:card.querySelector('.pour i')}); $('squad').append(card);
		});
		this.objective = replayNode('div', 'glass'); this.objective.id = 'objective'; this.objective.innerHTML = '<div class="row"><span class="muted">油桶</span><b class="num"></b></div><div class="bar"><i></i></div>'; this.objective.hidden = true; $('squad').append(this.objective);
	}
	update(frame, time) {
		this.updateKillFeed(time);
		this.time = time; const entities = new Map(frame.entities.map(a => [a.id, a])), put = (el, key, value) => { if (el['_' + key] !== value) { el['_' + key] = value; el[key] = value; } }, width = (el, value) => { if (el._width !== value) { el._width = value; el.style.width = value; } };
		for (const bot of this.bots) {
			// One card per survivor slot: a bot and the player who took it over (or the reverse) share it.
			const card = this.cards.get(bot.id), present = bot.members.map(m => entities.get(m.id)).filter(Boolean), actor = present.find(a => a.team === 2 && a.life !== 2) || present[0];
			card.card.classList.toggle('followed', !!actor && this.actions.camera.follow === actor.id); if (!actor) continue;
			if (bot.current !== actor.id) { bot.current = actor.id; card.name.textContent = this.actorById.get(actor.id)?.name || bot.name; }
			const status = actorStatus(actor), down = actor.life === 3, permanent = Math.max(0, actor.health), temporary = down ? 0 : Math.max(0, (actor.buffer?.health || 0) - Math.max(0, time - (actor.buffer?.time ?? time)) * (actor.buffer?.rate || 0)), maximum = actor.maxHealth;
			put(card.state, 'textContent', status); put(card.state, 'className', 'state' + (down ? ' down' : status === '受控' ? ' held' : status === '交互' ? ' use' : '')); put(card.hp, 'innerHTML', Math.round(permanent + temporary) + (temporary >= 1 ? '<small>+' + Math.round(temporary) + '</small>' : '')); card.bar.classList.toggle('down', down);
			width(card.perm, clamp(permanent / maximum * 100, 0, 100).toFixed(1) + '%'); width(card.temp, clamp(temporary / maximum * 100, 0, 100 - permanent / maximum * 100).toFixed(1) + '%');
			for (let slot = 0; slot < card.slots.length; slot++) {
				const item = actor.inventory.find(item => item.slot === (slot === 5 ? 'carried' : 'slot' + slot)), cell = card.slots[slot]; cell.cell.hidden = slot === 5 && !item; cell.cell.classList.toggle('empty', !item); cell.cell.classList.toggle('active', !!item && (item.active || actor.active === item.id));
				put(cell.name, 'textContent', item ? weaponNames[item.classname.replace(/^weapon_/, '')] || item.classname.replace(/^weapon_/, '') : '—');
				const image = item && (this.hudIcons[this.manifest.models[item.model]?.path] || this.hudIcons[item.classname]);
				if (cell.image !== image) { cell.image = image; cell.icon.hidden = !image; cell.name.hidden = !!image; if (image) { cell.icon.width = image.width; cell.icon.height = image.height; cell.icon.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.rgba.buffer, image.rgba.byteOffset, image.rgba.byteLength), image.width, image.height), 0, 0); } }
				const firearm = item && item.ammoType >= 0 && item.clip >= 0 && (slot === 0 || slot === 1 && (item.classname === 'weapon_pistol' || item.classname === 'weapon_pistol_magnum'));
				put(cell.ammo, 'hidden', !firearm); put(cell.clip, 'textContent', firearm ? String(item.clip) : ''); put(cell.reserve, 'textContent', firearm ? '/' + (slot === 1 ? '∞' : item.reserve ?? '—') : '');
				put(cell.cell, 'title', item ? cell.name.textContent + (firearm ? ' · ' + cell.clip.textContent + cell.reserve.textContent : '') + (item.active || actor.active === item.id ? ' · 当前手持' : '') : ''); if (cell.icon._label !== cell.name.textContent) { cell.icon._label = cell.name.textContent; cell.icon.setAttribute('aria-label', cell.name.textContent); }
			}
			const use = actor.use, progress = use?.duration > 0 ? clamp((time - use.start) / use.duration, 0, 1) : null; put(card.pour, 'hidden', progress === null); if (progress !== null) width(card.pourFill, (progress * 100).toFixed(1) + '%');
		}
		const goal = frame.objective; this.objective.hidden = !goal || goal.required <= 0; if (goal?.required > 0) { this.objective.querySelector('b').textContent = goal.current + ' / ' + goal.required; this.objective.querySelector('i').style.width = goal.current / goal.required * 100 + '%'; }
		$('playhead').style.transform = `translateX(${this.timeX(time)}px)`; put($('clock'), 'innerHTML', fmtTime(this.campaign.offset + time) + ' <small>/ ' + fmtTime(this.campaign.duration, 0) + '</small>');
		// Event rows change class only when the playhead moves by a visible amount.
		if (!(Math.abs(time - this.highlightedAt) < .1)) { this.highlightedAt = time; this.highlightEvents(); }
	}
	updateKillFeed(time) {
		const end = replayAt(this.notices, time), start = Math.max(end - 3, replayAt(this.notices, time - 6) + 1);
		if (start === this.noticeStart && end === this.noticeEnd) return;
		this.noticeStart = start; this.noticeEnd = end;
		const nodes = [], name = actor => { const node = replayNode('b', '', replayTypes[actor.type]?.[0] || actor.name); node.style.color = actor.color || replayTypes[actor.type]?.[1] || '#a8cad8'; return node; };
		for (let i = start; i <= end; i++) {
			const [, source, target, down, weapon] = this.notices[i], row = replayNode('div', 'kill-row'), label = weaponNames[weapon] || ({dual_pistols:'双枪', entityflame:'火焰', inferno:'火焰', prop_minigun:'固定机枪', prop_physics:'物理道具', tank_rock:'投石', tank_claw:'重拳'})[weapon] || (weapon.endsWith('_claw') ? '爪击' : weapon);
			row.append(name(source));
			const image = this.hudIcons['notice:' + weapon] || this.hudIcons['weapon_' + weapon];
			if (image) {
				const icon = replayNode('canvas'); icon.width = image.width; icon.height = image.height; icon.setAttribute('role','img'); icon.setAttribute('aria-label',label); icon.title = label;
				icon.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.rgba.buffer,image.rgba.byteOffset,image.rgba.byteLength),image.width,image.height),0,0); row.append(icon);
			} else if (label) row.append(replayNode('span','kill-weapon',label));
			row.append(replayNode('span',down ? 'kill-down' : 'kill-death',down ? '击倒' : '击杀'),name(target)); nodes.push(row);
		}
		$('killFeed').replaceChildren(...nodes);
	}
	buildFilters() {
		const el = $('filters'); el.replaceChildren();
		for (const bot of this.bots) { const users = bot.members.map(m => m.userid), chip = replayChip(bot.name, this.filter.bots.has(bot.userid) ? '' : 'off'), dot = replayNode('i', 'dot'); dot.style.setProperty('--c', bot.color); chip.prepend(dot); chip.onclick = () => { const on = this.filter.bots.has(bot.userid); for (const user of users) on ? this.filter.bots.delete(user) : this.filter.bots.add(user); this.buildFilters(); this.filterEvents(); }; el.append(chip); }
		for (const [cat, [label]] of Object.entries(this.categories)) { const chip = replayChip(label, this.filter.cats[cat] ? '' : 'off'); chip.onclick = () => { this.filter.cats[cat] = !this.filter.cats[cat]; this.buildFilters(); this.filterEvents(); }; el.append(chip); }
	}
	filterEvents() { this.visibleEvents = this.events.filter(e => this.filter.cats[e.cat] && (!['hurt', 'incap', 'bleed'].includes(e.cat) || this.filter.bots.has(e.userid))); this.eventStart = -1; this.highlightedAt = NaN; $('events').scrollTop = 0; this.renderEvents(); }
	eventView(event) {
		const actor = this.actorById.get(event.actor), color = actor?.color || replayTypes[event.type]?.[1] || '#a8cad8';
		if (event.cat === 'hurt' || event.cat === 'incap' || event.cat === 'bleed') return {color, who:actor?.name || event.bot || '', tag:event.cause || '', amount:event.cat === 'incap' ? '倒地' : '−' + event.damage, sub:event.cat === 'incap' ? event.cause || '' : '剩余 ' + event.health_after + ' HP'};
		if (event.cat === 'pour') return {color:'#5ee3a1', who:'油桶灌入', tag:'', amount:event.done + ' / ' + event.total, sub:'剩余 ' + (event.total - event.done) + ' 桶'};
		return {color, who:(replayTypes[event.type]?.[0] || actor?.name || event.type) + (event.phase === 'death' ? ' 被击杀' : ' 出现'), tag:'', amount:'', sub:event.health > 0 ? event.health + ' HP' : ''};
	}
	renderEvents() {
		const el = $('events'), height = 61, start = Math.max(0, Math.floor(el.scrollTop / height) - 8), end = Math.min(this.visibleEvents.length, start + Math.ceil((el.clientHeight || 600) / height) + 16); if (start === this.eventStart && end === this.eventEnd) return;
		this.eventStart = start; this.eventEnd = end; const nodes = [], before = replayNode('div', 'event-spacer'); before.style.height = start * height + 'px'; nodes.push(before);
		for (let index = start; index < end; index++) { const event = this.visibleEvents[index], view = this.eventView(event), row = replayNode('div', 'ev'); row.dataset.index = index; const what = replayNode('div', 'what'), dot = replayNode('i', 'dot'); dot.style.setProperty('--c', view.color); what.append(dot, replayNode('span', '', view.who)); if (view.tag) what.append(replayNode('span', 'tag', view.tag)); row.append(replayNode('time', '', fmtTime(event.t)), what, replayNode('span', 'amt ' + (event.cat === 'incap' ? 'incap' : 'hurt'), view.amount), replayNode('div', 'sub', view.sub)); row.onclick = () => this.jumpTo(event); nodes.push(row); }
		const after = replayNode('div', 'event-spacer'); after.style.height = (this.visibleEvents.length - end) * height + 'px'; nodes.push(after); if (!this.visibleEvents.length) nodes.push(replayNode('div', 'muted', '没有符合筛选的事件')); el.replaceChildren(...nodes); this.highlightEvents(false);
	}
	highlightEvents(scroll = true) {
		const index = replayFirst(this.visibleEvents, this.time - 1.5), el = $('events');
		for (const row of el.querySelectorAll('.ev')) { const event = this.visibleEvents[Number(row.dataset.index)]; row.classList.toggle('now', Math.abs(event.t - this.time) <= 1.5); row.classList.toggle('past', event.t < this.time - 1.5); }
		if (scroll && index < this.visibleEvents.length && !$('drawer').matches(':hover') && (index * 61 < el.scrollTop || index * 61 > el.scrollTop + el.clientHeight - 61)) { el.scrollTop = Math.max(0, index * 61 - 61); this.renderEvents(); }
	}
	jumpTo(event) { this.actions.seek(event.phase === 'spawn' ? event.t + .3 : Math.max(0, event.t - (event.cat === 'hurt' || event.cat === 'incap' ? 1.5 : 2))); this.actions.follow(event.phase === 'death' ? 'team' : event.actor || 'team', event.type === 'tank' ? 900 : 650); }
	stepEvent(direction) { let index = replayFirst(this.visibleEvents, this.time + (direction > 0 ? 1.6 : 1.4)); if (direction < 0) index--; while (index >= 0 && index < this.visibleEvents.length) { const event = this.visibleEvents[index]; if (event.cat !== 'bleed') { this.jumpTo(event); return; } index += direction; } }
	timeX(time) { return 74 + (this.campaign.offset + time) / (this.campaign.duration || 1) * (this.timeWidth - 80); }
	timeAt(x) { return clamp((x - 74) / (this.timeWidth - 80) * this.campaign.duration, 0, this.campaign.duration); }
	drawTimeline() {
		const canvas = $('timeCanvas'), g = canvas.getContext('2d'), dpr = Math.min(devicePixelRatio || 1, 2), width = $('timeline').clientWidth, chapterBand = this.campaign.entries.length > 1 ? 17 : 0, height = chapterBand + 20 + this.bots.length * 18;
		this.timeWidth = width; canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr); canvas.style.height = height + 'px'; g.setTransform(dpr, 0, 0, dpr, 0, 0); g.clearRect(0, 0, width, height); g.font = '11px "Segoe UI",system-ui,sans-serif'; g.textBaseline = 'middle';
		if (chapterBand) {
			g.fillStyle = '#a8b1c1'; g.fillText('关卡',10,8);
			this.campaign.entries.forEach((entry, index) => {
				const x = this.timeX(entry.start - this.campaign.offset), w = entry.duration / this.campaign.duration * (width - 80);
				g.fillStyle = index === this.campaign.index ? 'rgba(255,176,76,.35)' : 'rgba(255,255,255,.09)';
				g.fillRect(x,0,Math.max(0,w - 1),15);
				if (w > 30) { g.fillStyle = '#e6e4dd'; g.fillText(entry.map.split('_')[0],x + 3,8,w - 5); }
			});
			g.translate(0,chapterBand);
		}
		g.fillStyle = 'rgba(255,255,255,.035)'; g.fillRect(74, 2, width - 80, 15); g.fillStyle = '#7d889c'; g.fillText('事件', 10, 10);
		for (const actor of this.manifest.entities) { const type = actorType(actor); if (type !== 'tank' && type !== 'witch') continue; const death = this.events.find(event => event.actor === actor.id && event.phase === 'death'), left = this.timeX(actor.start), right = this.timeX(death ? death.t : actor.end); g.fillStyle = type === 'tank' ? 'rgba(255,68,93,.32)' : 'rgba(255,240,160,.25)'; g.beginPath(); g.roundRect(left, 4, Math.max(3, right - left), 11, 3); g.fill(); if (right - left > 34) { g.fillStyle = '#ffd0d6'; g.fillText(replayTypes[type][0], left + 5, 9); } }
		for (const event of this.events) { if (event.cat === 'hurt' || event.cat === 'bleed' || event.cat === 'boss') continue; const x = this.timeX(event.t); g.fillStyle = event.cat === 'incap' ? DOWNED : event.cat === 'pour' ? '#5ee3a1' : replayTypes[event.type]?.[1] || '#a8cad8'; if (event.cat === 'pour') { g.fillRect(x - 1, 4, 2, 11); continue; } g.beginPath(); if (event.cat === 'incap') { g.moveTo(x, 3); g.lineTo(x + 5.5, 9); g.lineTo(x, 15); g.lineTo(x - 5.5, 9); g.closePath(); g.fill(); g.strokeStyle = '#fff'; g.lineWidth = 1; g.stroke(); continue; } else g.arc(x, 9, 2.5, 0, Math.PI * 2); g.fill(); }
		this.bots.forEach((bot, index) => {
			const top = 20 + index * 18, bottom = top + 15, rows = bot.members.length > 1 ? bot.members.flatMap(m => this.manifest.timeline.health[m.id] || []).sort((a, b) => a[0] - b[0]) : this.manifest.timeline.health[bot.id] || []; g.fillStyle = 'rgba(255,255,255,.03)'; g.fillRect(74, top, width - 80, 15); g.fillStyle = bot.color; g.beginPath(); g.arc(14, top + 7.5, 3.5, 0, Math.PI * 2); g.fill(); g.fillStyle = '#b4bfd1'; g.fillText(bot.name, 23, top + 7.5);
			if (rows.length) { g.beginPath(); rows.forEach((row, i) => { const x = this.timeX(row[0]), y = bottom - 1 - clamp((row[1] + (row[4] === 3 ? 0 : row[2])) / row[3], 0, 1) * 12; i ? g.lineTo(x, y) : g.moveTo(x, y); }); g.lineTo(this.timeX(rows.at(-1)[0]), bottom); g.lineTo(this.timeX(rows[0][0]), bottom); g.closePath(); g.fillStyle = bot.color + '20'; g.fill(); }
			// Downed spans: hatched band over the whole lane, then a dashed downed-colour line.
			if (!this.downedPattern) { const tile = document.createElement('canvas'); tile.width = tile.height = 6; const t = tile.getContext('2d'); t.fillStyle = 'rgba(255,46,126,.22)'; t.fillRect(0, 0, 6, 6); t.strokeStyle = DOWNED; t.lineWidth = 1.6; t.beginPath(); t.moveTo(-1, 7); t.lineTo(7, -1); t.moveTo(5, 7); t.lineTo(7, 5); t.moveTo(-1, 1); t.lineTo(1, -1); t.stroke(); this.downedPattern = g.createPattern(tile, 'repeat'); }
			for (let k = 1; k < rows.length; k++) if (rows[k - 1][4] === 3) { const left = this.timeX(rows[k - 1][0]), right = Math.max(left + 2, this.timeX(rows[k][0])); g.fillStyle = this.downedPattern; g.fillRect(left, top, right - left, 15); }
			g.lineWidth = 1.5; for (let k = 1; k < rows.length; k++) { const a = rows[k - 1], b = rows[k], y = row => bottom - 1 - clamp((row[1] + (row[4] === 3 ? 0 : row[2])) / row[3], 0, 1) * 12, down = a[4] === 3; g.strokeStyle = down ? DOWNED : bot.color; g.lineWidth = down ? 2 : 1.5; g.setLineDash(down ? [3, 2] : []); g.beginPath(); g.moveTo(this.timeX(a[0]), y(a)); g.lineTo(this.timeX(b[0]), y(b)); g.stroke(); }
			g.setLineDash([]); g.lineWidth = 1.5;
			g.fillStyle = '#ff5b6b'; for (const event of this.events) if (event.actor === bot.id && event.cat === 'hurt') g.fillRect(this.timeX(event.t) - .5, bottom - 4, 1.5, 4);
		}); $('playhead').style.left = '0'; $('playhead').style.transform = `translateX(${this.timeX(this.time)}px)`;
	}
	bindTimeline(signal) {
		const el = $('timeline'); let scrub = false;
		const point = e => this.timeAt(e.clientX - el.getBoundingClientRect().left);
		const inChapter = t => t >= this.campaign.offset && (t < this.campaign.offset + this.manifest.duration || this.campaign.index === this.campaign.entries.length - 1);
		const preview = t => {
			if (inChapter(t)) this.actions.seek(t - this.campaign.offset);
			$('playhead').style.transform = 'translateX(' + this.timeX(t - this.campaign.offset) + 'px)';
		};
		el.addEventListener('pointerdown', e => { scrub = true; el.setPointerCapture(e.pointerId); preview(point(e)); }, {signal});
		el.addEventListener('pointerup', e => { if (scrub) { scrub = false; this.actions.seekCampaign(point(e)); } }, {signal});
		for (const name of ['pointercancel','lostpointercapture']) el.addEventListener(name, () => scrub = false, {signal});
		el.addEventListener('pointerleave', () => { $('tip').style.display = 'none'; $('hoverLine').style.display = 'none'; }, {signal});
		el.addEventListener('pointermove', e => {
			const x = e.clientX - el.getBoundingClientRect().left, at = this.timeAt(x), time = at - this.campaign.offset;
			if (scrub) preview(at);
			if (x < 74) { $('tip').style.display = 'none'; return; }
			const tip = $('tip'), chapter = this.campaign.entries.findLast(c => c.start <= at) || this.campaign.entries[0];
			tip.replaceChildren(replayNode('div','t',this.campaign.entries.length > 1 ? chapter.map + ' · ' + fmtTime(at - chapter.start) : fmtTime(at)));
			if (inChapter(at)) {
				for (const bot of this.bots) {
					const rows = this.manifest.timeline.health[bot.id] || [], i = replayAt(rows,time), p = rows[i], next = rows[i+1];
					const temporary = p && next && p[1] === next[1] && p[4] === next[4] ? p[2] + (next[2]-p[2])*clamp((time-p[0])/(next[0]-p[0]),0,1) : p?.[2] || 0;
					const row = replayNode('div','r'), dot = replayNode('i','dot'); dot.style.setProperty('--c',bot.color);
					row.append(dot,replayNode('span','',bot.name),replayNode('b','',p ? Math.round(p[1]+temporary) : '—')); tip.append(row);
				}
				const span = this.campaign.duration * 5 / (this.timeWidth - 80), start = replayFirst(this.visibleEvents,time-span);
				for (let i=start,count=0; i<this.visibleEvents.length && this.visibleEvents[i].t<=time+span && count<3; i++) {
					const event=this.visibleEvents[i]; if(event.cat==='bleed')continue;
					const view=this.eventView(event), row=replayNode('div','r','● '+view.who+' '+String(view.amount||''));
					row.style.marginTop='4px'; row.style.color='#ffcf8a'; tip.append(row); count++;
				}
			}
			tip.style.display='block'; tip.style.left=clamp(x,90,this.timeWidth-90)+'px'; $('hoverLine').style.display='block'; $('hoverLine').style.left=x+'px';
		},{signal});
	}
};


// ---- Audio --------------------------------------------------------------------------------
// Survivor, special and common infected sounds and the horde music, through WebAudio. New
// recordings carry the server's sounds as {kind:'sound', sample, channel, volume, level, pitch,
// origin, entity, type} events; older ones are inferred from game events (weapon_fire through
// scripts/weapon_*.txt, special-infected abilities through their soundscripts, common infected
// hurt/death through the game's own sample folders). Horde music is always inferred from
// create_panic_event .. panic_event_finished (it is client-side in L4D2, so never captured).
// Samples come from sound/ in the user's L4D2 files (loose or VPK) through the loader worker.
globalThis.ReplayAudio = class {
	constructor(manifest, read, ui) {
		this.manifest = manifest; this.read = read; this.ui = ui; this.buffers = new Map(); this.bufferBytes = 0; this.active = new Set(); this.channels = new Map(); this.lastHurt = new Map(); this.captured = false; this.music = null; this.stats = {played:0, skipped:0, missing:0, ms:0};
	}
	// Called from a user gesture (browser autoplay rules).
	enable() {
		if (!this.ctx) { const Context = globalThis.AudioContext || globalThis.webkitAudioContext; if (!Context) return false; this.ctx = new Context(); this.master = this.ctx.createGain(); this.master.connect(this.ctx.destination); }
		this.ctx.resume(); return true;
	}
	dispose() { this.stopAll(); this.ctx?.close(); this.ctx = null; }
	stopAll() { for (const node of this.active) { try { node.source.stop(); } catch {} } this.active.clear(); this.channels.clear(); this.stopMusic(); }
	static category(sample, type) {
		const s = sample.toLowerCase();
		if (s.startsWith('music/')) return 'music';
		if (s.startsWith('npc/infected/')) return 'common';
		if (/^player\/(smoker|boomer|hunter|jockey|charger|spitter|tank|witch|hulk|zombie)|^player\/footsteps\/(infected|boomer|smoker|hunter|jockey|charger|spitter|tank)|^npc\/(witch|mega_mob)/.test(s)) return 'special';
		if (type === 'common' || type === 'infected') return 'common';
		if (type && !['survivor', 'player'].includes(type)) return 'special';
		return 'survivor';
	}
	enabledFor(category) { return {survivor:prefs.audioSurvivor, special:prefs.audioSpecial, common:prefs.audioCommon, music:prefs.audioMusic}[category] !== false; }
	// ---- samples -------------------------------------------------------------------------
	buffer(sample) {
		const path = sample.toLowerCase().replace(/\\/g, '/').replace(/^[*#)(^<>@!?&~$`+%]+/, '');
		if (!this.buffers.has(path)) this.buffers.set(path, (async () => {
			const bytes = await this.read('sound/' + path); if (!bytes) { this.stats.missing++; return null; }
			let buffer = null; try { buffer = await this.ctx.decodeAudioData(bytes.slice().buffer); } catch { buffer = ReplayAudio.decodeAdpcm(this.ctx, bytes); }
			if (buffer) this.bufferBytes += buffer.length * buffer.numberOfChannels * 4;
			if (this.bufferBytes > 96e6) { for (const [key, promise] of this.buffers) { if (key === path) continue; this.buffers.delete(key); promise.then(b => { if (b) this.bufferBytes -= b.length * b.numberOfChannels * 4; }); if (this.bufferBytes < 64e6) break; } }
			return buffer;
		})());
		return this.buffers.get(path);
	}
	// MS-ADPCM (WAVE_FORMAT_ADPCM = 2), which decodeAudioData does not take.
	static decodeAdpcm(ctx, bytes) {
		const d = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength); if (String.fromCharCode(...bytes.subarray(0, 4)) !== 'RIFF') return null;
		let at = 12, fmt = null, data = null;
		while (at + 8 <= bytes.length) { const id = String.fromCharCode(...bytes.subarray(at, at + 4)), size = d.getUint32(at + 4, true); if (id === 'fmt ') fmt = at + 8; else if (id === 'data') data = [at + 8, Math.min(size, bytes.length - at - 8)]; at += 8 + size + (size & 1); }
		if (!fmt || !data || d.getUint16(fmt, true) !== 2) return null;
		const channels = d.getUint16(fmt + 2, true), rate = d.getUint32(fmt + 4, true), align = d.getUint16(fmt + 12, true), perBlock = d.getUint16(fmt + 18, true), ncoef = d.getUint16(fmt + 20, true), coef = [];
		for (let i = 0; i < ncoef; i++) coef.push([d.getInt16(fmt + 22 + i * 4, true), d.getInt16(fmt + 24 + i * 4, true)]);
		const adapt = [230, 230, 230, 230, 307, 409, 512, 614, 768, 614, 512, 409, 307, 230, 230, 230], blocks = Math.floor(data[1] / align), frames = blocks * perBlock, out = Array.from({length:channels}, () => new Float32Array(frames));
		for (let b = 0; b < blocks; b++) {
			let p = data[0] + b * align; const state = [];
			for (let c = 0; c < channels; c++) state.push({pred:Math.min(bytes[p + c], ncoef - 1)}); p += channels;
			for (let c = 0; c < channels; c++) { state[c].delta = d.getInt16(p, true); p += 2; }
			for (let c = 0; c < channels; c++) { state[c].s1 = d.getInt16(p, true); p += 2; }
			for (let c = 0; c < channels; c++) { state[c].s2 = d.getInt16(p, true); p += 2; }
			const base = b * perBlock; for (let c = 0; c < channels; c++) { out[c][base] = state[c].s2 / 32768; out[c][base + 1] = state[c].s1 / 32768; }
			let n = 2 * channels; const total = perBlock * channels;
			for (; n < total && p < data[0] + (b + 1) * align; p++) for (const nibble of [bytes[p] >> 4, bytes[p] & 15]) {
				if (n >= total) break; const c = n % channels, s = state[c], signed = nibble & 8 ? nibble - 16 : nibble, [c1, c2] = coef[s.pred];
				let sample = ((s.s1 * c1 + s.s2 * c2) >> 8) + signed * s.delta; sample = Math.max(-32768, Math.min(32767, sample));
				s.s2 = s.s1; s.s1 = sample; s.delta = Math.max(16, (adapt[nibble] * s.delta) >> 8); out[c][base + Math.floor(n / channels)] = sample / 32768; n++;
			}
		}
		const buffer = ctx.createBuffer(channels, frames || 1, rate); out.forEach((channel, c) => buffer.copyToChannel(channel, c)); return buffer;
	}
	// ---- soundscripts (inference only) ------------------------------------------------------
	scripts() {
		return this.scriptTable ||= (async () => {
			const table = new Map(), text = async path => { const bytes = await this.read(path); return bytes ? new TextDecoder('latin1').decode(bytes) : ''; };
			const manifest = await text('scripts/game_sounds_manifest.txt'), files = [...new Set((manifest.match(/scripts\/[\w\/.-]+\.txt/gi) || []).map(p => p.toLowerCase()))];
			for (const file of files) ReplayAudio.parseScripts(await text(file), table);
			return table;
		})();
	}
	static parseScripts(text, table) {
		const tokens = text.replace(/\/\/[^\n]*/g, '').match(/"[^"]*"|[{}]|[^\s{}"]+/g) || []; let i = 0;
		const value = () => { const t = tokens[i++]; return t?.startsWith('"') ? t.slice(1, -1) : t; };
		const block = entry => { while (i < tokens.length && tokens[i] !== '}') { const key = value()?.toLowerCase(); if (tokens[i] === '{') { i++; block(entry); i++; } else { const v = value(); if (key === 'wave') entry.waves.push(v); else if (!(key in entry)) entry[key] = v; } } };
		while (i < tokens.length) { const name = value(); if (tokens[i] !== '{') continue; i++; const entry = {waves:[]}; block(entry); i++; if (name) table.set(name.toLowerCase(), entry); }
	}
	static level(text) {
		if (text == null) return 75; const value = String(text).toUpperCase(), number = value.match(/(\d+)\s*DB/); if (number) return Number(number[1]);
		return {SNDLVL_NONE:0, SNDLVL_NORM:75, SNDLVL_TALKING:80, SNDLVL_STATIC:66, SNDLVL_IDLE:70, SNDLVL_GUNFIRE:140, SNDLVL_DISHWASHER:65}[value.trim()] ?? (Number(value) || 75);
	}
	static range(text, fallback) { if (text == null) return fallback; const parts = String(text).match(/[\d.]+/g)?.map(Number) || []; if (/VOL_NORM|PITCH_NORM/i.test(text)) return fallback; if (!parts.length) return fallback; return parts.length > 1 ? parts[0] + Math.random() * (parts[1] - parts[0]) : parts[0]; }
	async script(name, origin, entity, category) {
		const entry = (await this.scripts()).get(name.toLowerCase()); if (!entry?.waves.length) return;
		const wave = entry.waves[Math.floor(Math.random() * entry.waves.length)];
		this.play({sample:wave, origin, entity, channel:/VOICE/i.test(entry.channel || '') ? 2 : /WEAPON/i.test(entry.channel || '') ? 1 : 0, volume:ReplayAudio.range(entry.volume, 1), level:ReplayAudio.level(entry.soundlevel), pitch:ReplayAudio.range(entry.pitch, 100), category});
	}
	async weaponScript(weapon) {
		const cache = this.weaponScripts ||= new Map(); if (!cache.has(weapon)) cache.set(weapon, (async () => { const bytes = await this.read('scripts/weapon_' + weapon + '.txt'); return bytes ? new TextDecoder('latin1').decode(bytes).match(/"single_shot"\s+"([^"]+)"/i)?.[1] || null : null; })());
		return cache.get(weapon);
	}
	// ---- playback ---------------------------------------------------------------------------
	async play(sound, at = this.ctx.currentTime) {
		const category = sound.category || ReplayAudio.category(sound.sample, sound.type); if (!this.enabledFor(category)) return;
		// Source falloff (snd_dma SND_GetGainFromMult): gain = min(1, ref / distance) with the reference distance
		// 36 * 10^((level - 60) / 20) units (75 dB: 202 u, 85 dB: 640 u, 95 dB: 2025 u). Level 0 rows are sounds the
		// server sent to one player (a Jockey's ride loop to its victim); here they are heard from where they are, at 75 dB.
		// The reference distance is capped at 300 units and the falloff is 1.4x steeper than Source's, so
		// loud voices (special infected at 95-105 dB) also fade with distance from the camera (user 2026-11-18).
		const level = sound.level > 0 ? sound.level : 75, reference = Math.min(300, Math.max(12, 36 * Math.pow(10, (level - 60) / 20)));
		const minor = ReplayAudio.minor(sound.sample);
		if (sound.origin && this.listener) { const distance = Math.hypot(...sound.origin.map((v, k) => v - this.listener[k])); if (reference / (reference + ReplayAudio.rolloff * Math.max(0, distance - reference)) < (minor ? .04 : .02)) { this.stats.skipped++; return; } }
		if (!this.makeRoom(minor)) { this.stats.skipped++; return; }
		const buffer = await this.buffer(sound.sample); if (!buffer || !this.ctx) return;
		// A sample read for the first time can take longer than the sound's moment (every special-infected death
		// line is a separate file). Footsteps and gore are dropped; anything else starts late, skipping what passed.
		const late = this.ctx.currentTime - at; let offset = 0;
		if (late > .25) { if (minor || late > Math.min(2, buffer.duration * .6)) { this.stats.skipped++; return; } offset = late; }
		if (!this.makeRoom(minor)) { this.stats.skipped++; return; }
		const key = sound.entity != null && sound.channel && sound.channel !== 6 ? sound.entity + ':' + sound.channel : null;
		if (key && this.channels.has(key)) { const old = this.channels.get(key); try { old.source.stop(); } catch {} this.active.delete(old); }
		const source = this.ctx.createBufferSource(), gain = this.ctx.createGain(); source.buffer = buffer; source.playbackRate.value = (sound.pitch || 100) / 100 * (this.rate || 1); gain.gain.value = Math.max(0, Math.min(1, sound.volume ?? 1)) * (ReplayAudio.gun(sound.sample) ? ReplayAudio.gunScale : 1);
		let tail = gain; source.connect(gain);
		if (sound.origin) { const panner = new PannerNode(this.ctx, {panningModel:'equalpower', distanceModel:'inverse', refDistance:reference, maxDistance:1e6, rolloffFactor:ReplayAudio.rolloff, positionX:sound.origin[0], positionY:sound.origin[1], positionZ:sound.origin[2]}); gain.connect(panner); tail = panner; }
		tail.connect(category === 'music' ? this.musicGain() : this.master);
		const node = {source, key, minor, started:this.ctx.currentTime}; this.active.add(node); if (key) this.channels.set(key, node);
		source.onended = () => { this.active.delete(node); if (key && this.channels.get(key) === node) this.channels.delete(key); };
		source.start(0, offset); this.stats.played++;
	}
	// Footsteps, gore and hit thuds: many per second, never worth an important sound's slot.
	static minor(sample) { return /footsteps|jumplanding|\/gore\/|\/hit\/|been_shot|swing|bullet_impact/i.test(sample || ''); }
	// At most 48 sounds at once. A full mix drops a new minor sound; anything else replaces the oldest minor
	// one (before, a special infected's death line was dropped whenever 40 footsteps and groans were playing).
	makeRoom(minor) {
		if (this.active.size < 48) return true; if (minor) return false;
		let oldest = null; for (const node of this.active) if (node.minor && (!oldest || node.started < oldest.started)) oldest = node;
		if (!oldest) return false; try { oldest.source.stop(); } catch {} this.active.delete(oldest); if (oldest.key && this.channels.get(oldest.key) === oldest) this.channels.delete(oldest.key); return true;
	}
	musicGain() { if (!this.musicNode) { this.musicNode = this.ctx.createGain(); this.musicNode.connect(this.master); } return this.musicNode; }
	// Zombat: intro, then the A/B drum loops queue each other (MusicAutoQueue) until the panic ends.
	async startMusic() {
		if (this.music || !this.enabledFor('music')) return; const music = this.music = {stopped:false, sources:[]}; this.musicGain().gain.cancelScheduledValues(this.ctx.currentTime); this.musicGain().gain.setValueAtTime(.55, this.ctx.currentTime);
		const table = await this.scripts(); let when = this.ctx.currentTime + .05, step = 0;
		const next = async () => {
			if (music.stopped || !this.ctx) return; const name = step === 0 ? 'event.zombat_intro_1' : step === 1 ? 'event.zombat_1' : step % 2 ? 'event.zombat_b_1' : 'event.zombat_a_1'; step++;
			const entry = table.get(name), wave = entry?.waves[Math.floor(Math.random() * entry.waves.length)], buffer = wave && await this.buffer(wave); if (!buffer || music.stopped) return;
			const source = this.ctx.createBufferSource(); source.buffer = buffer; source.connect(this.musicGain()); source.start(Math.max(when, this.ctx.currentTime)); music.sources.push(source); if (music.sources.length > 4) music.sources.shift();
			when = Math.max(when, this.ctx.currentTime) + buffer.duration; music.timer = setTimeout(next, Math.max(0, (when - this.ctx.currentTime - .5) * 1000));
		};
		next();
	}
	stopMusic(fade = 0) {
		const music = this.music; if (!music) return; music.stopped = true; clearTimeout(music.timer); this.music = null;
		if (fade && this.ctx) { const g = this.musicGain().gain; g.setValueAtTime(g.value, this.ctx.currentTime); g.linearRampToValueAtTime(0, this.ctx.currentTime + fade); setTimeout(() => { for (const s of music.sources) try { s.stop(); } catch {} }, fade * 1000); }
		else for (const s of music.sources) try { s.stop(); } catch {}
	}
	// Old recordings: game events -> sounds.
	infer(event, states) {
		const name = event.name, actorId = event.actor ?? event.id, state = states.get(actorId), origin = state?.origin ? [state.origin[0], state.origin[1], state.origin[2] + 40] : event.position || event.origin, type = this.ui.actorById.get(actorId)?.type;
		const si = {smoker:'SmokerZombie', boomer:'BoomerZombie', hunter:'HunterZombie', jockey:'JockeyZombie', charger:'ChargerZombie', spitter:'SpitterZombie', tank:'HulkZombie', witch:'WitchZombie'};
		if (name === 'weapon_fire') { const weapon = String(event.weapon || '').replace(/^weapon_/, ''); if (!weapon || /melee|claw|pain_pills|adrenaline|first_aid|defib|molotov|pipe_bomb|vomitjar|gascan|propane|oxygen|chainsaw/.test(weapon)) return; this.weaponScript(weapon).then(script => script && this.script(script, origin, actorId, type === 'survivor' || !type ? 'survivor' : 'special')); return; }
		const abilities = {ability_tongue:'SmokerZombie.TongueAttack', ability_vomit:'BoomerZombie.Attack', ability_lunge:'HunterZombie.Lunge', ability_leap:'JockeyZombie.Pounce', ability_charge:'ChargerZombie.Charge', ability_spit:'SpitterZombie.Spit', ability_throw:'HulkZombie.Throw'};
		const scripted = {tongue_grab:'SmokerZombie.TongueHit', lunge_pounce:'HunterZombie.Pounce.Hit', jockey_ride:'JockeyZombie.Ride', charger_carry_start:'ChargerZombie.HitPerson', charger_pummel_start:'ChargerZombie.Pummel', boomer_exploded:'BoomerZombie.Detonate', spit_burst:'SpitterZombie.Acid', tank_spawn:'HulkZombie.Yell', witch_harasser_set:'WitchZombie.Rage'};
		if (name === 'ability_use' && abilities[event.ability]) return this.script(abilities[event.ability], origin, actorId, 'special');
		if (scripted[name]) return this.script(scripted[name], origin, actorId, 'special');
		if (name === 'player_death' && si[type]) return this.script(si[type] + (type === 'tank' || type === 'witch' ? '.Die' : '.Death'), origin, actorId, 'special');
		if (name === 'infected_death' || name === 'infected_hurt') {
			if (name === 'infected_hurt') { const last = this.lastHurt.get(actorId) || -9; if (event.t - last < .6) return; this.lastHurt.set(actorId, event.t); }
			const female = /female|nurse/i.test(this.manifest.models[state?.model]?.path || ''), family = ReplayAudio.common[(name === 'infected_death' ? 'die' : 'shot') + (female ? 'F' : 'M')];
			return this.play({sample:family[Math.floor(Math.random() * family.length)], origin, entity:actorId, channel:2, volume:.85, level:name === 'infected_death' ? 85 : 80, pitch:95 + Math.random() * 10, category:'common'});
		}
	}
	// Each rendered/ticked frame: new events since the last call, at most 2x playback (setting).
	update(frame, time, playing, speed, camera) {
		const started = performance.now();
		if (!this.ctx || !prefs.audio) { this.lastTime = time; return; }
		// The whole mix sits lower than the slider value (user 2026-11-18: overall too loud).
		this.master.gain.value = (prefs.audioVolume ?? .7) * ReplayAudio.masterScale;
		// Heard from the camera itself, so a distant view of a fight is quiet (it was heard from the orbit target).
		const target = camera.target, eye = camera.eye(), forward = ReplayRenderer.normalize(target.map((v, k) => v - eye[k])), listener = this.ctx.listener; this.listener = eye;
		if (listener.positionX) { listener.positionX.value = eye[0]; listener.positionY.value = eye[1]; listener.positionZ.value = eye[2]; listener.forwardX.value = forward[0]; listener.forwardY.value = forward[1]; listener.forwardZ.value = forward[2]; listener.upX.value = 0; listener.upY.value = 0; listener.upZ.value = 1; }
		const policy = prefs.audioSpeed || '2x', allowed = playing && (policy === 'pitch' || speed <= (policy === '1x' ? 1 : 2)); this.rate = policy === 'pitch' ? Math.min(speed, 4) : 1;
		if (!playing) { if (this.ctx.state === 'running') this.ctx.suspend(); this.lastTime = time; return; }
		if (this.ctx.state === 'suspended') this.ctx.resume();
		if (this.lastTime === undefined || time < this.lastTime || time - this.lastTime > .75 || !allowed) { if (this.lastTime !== undefined && (time < this.lastTime || time - this.lastTime > .75)) this.stopAll(); this.lastTime = time; if (!allowed) this.stopMusic(.5); return; }
		const states = new Map(frame.entities.map(state => [state.id, state])), events = frame.events || [];
		if (!this.captured) this.captured = events.some(event => event.kind === 'sound');
		for (const event of events) {
			if (!(event.t > this.lastTime && event.t <= time)) continue;
			if (event.kind === 'sound') { if (event.sample) this.play({sample:event.sample, origin:event.origin, entity:event.entity, channel:event.channel, volume:event.volume, level:event.level, pitch:event.pitch, type:event.type}); }
			else if (event.name === 'gascan_pour_completed' || event.name === 'objective' && event.cat === 'pour') {
				if (!events.some(e => e.kind === 'sound' && !(e.flags & 4) && Math.abs(e.t-event.t)<.12 && /(^|\/)survival_playerrec\.wav$/i.test(e.sample))) this.script('Scavenge.point_scored', null, null, 'survivor');
			}
			else if (event.name === 'weapon_fire' && ReplayAudio.clientSideFire.test(String(event.weapon || ''))) this.infer(event, states);
			else if (event.name === 'create_panic_event') this.startMusic();
			else if (event.name === 'panic_event_finished') this.stopMusic(3);
			else if (!this.captured) this.infer(event, states);
		}
		this.lastTime = time; this.stats.ms += performance.now() - started;
	}
};
ReplayAudio.masterScale = .2;
ReplayAudio.rolloff = 1.4;
ReplayAudio.gunScale = .5;
ReplayAudio.gun = sample => /^[^a-z]*weapons\//i.test(sample || '');
// Shotgun shots are client-side effects in L4D2: the server never sends their sound, so the viewer plays the
// weapon script's single_shot sound for each weapon_fire.
ReplayAudio.clientSideFire = /shotgun/i;
// Common infected sample folders (sound/npc/infected/action/...) seen in captured recordings; the
// soundscripts Zombie.Die/Zombie.Shot have no wave list (the game picks files in code).
ReplayAudio.common = {"dieM": ["npc/infected/action/die/male/death_48.wav", "npc/infected/action/die/male/death_44.wav", "npc/infected/action/die/male/death_40.wav", "npc/infected/action/die/male/death_43.wav", "npc/infected/action/die/male/death_42.wav", "npc/infected/action/die/male/death_47.wav", "npc/infected/action/die/male/death_41.wav", "npc/infected/action/die/male/death_49.wav", "npc/infected/action/die/male/death_45.wav", "npc/infected/action/die/male/death_46.wav"], "dieF": ["npc/infected/action/die/female/death_43.wav", "npc/infected/action/die/female/death_46.wav", "npc/infected/action/die/female/death_44.wav", "npc/infected/action/die/female/death_48.wav", "npc/infected/action/die/female/death_47.wav", "npc/infected/action/die/female/death_40.wav", "npc/infected/action/die/female/death_41.wav", "npc/infected/action/die/female/death_42.wav", "npc/infected/action/die/female/death_49.wav", "npc/infected/action/die/female/death_45.wav"], "shotM": ["npc/infected/action/been_shot/male/been_shot_36.wav", "npc/infected/action/been_shot/male/been_shot_35.wav", "npc/infected/action/been_shot/male/been_shot_34.wav", "npc/infected/action/been_shot/male/been_shot_32.wav", "npc/infected/action/been_shot/male/been_shot_37.wav", "npc/infected/action/been_shot/male/been_shot_33.wav", "npc/infected/action/been_shot/male/been_shot_30.wav", "npc/infected/action/been_shot/male/been_shot_31.wav"], "shotF": ["npc/infected/action/been_shot/female/been_shot_37.wav", "npc/infected/action/been_shot/female/been_shot_32.wav", "npc/infected/action/been_shot/female/been_shot_34.wav", "npc/infected/action/been_shot/female/been_shot_31.wav", "npc/infected/action/been_shot/female/been_shot_33.wav", "npc/infected/action/been_shot/female/been_shot_36.wav", "npc/infected/action/been_shot/female/been_shot_30.wav", "npc/infected/action/been_shot/female/been_shot_35.wav"]};
