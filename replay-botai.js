'use strict';
// BotAI decision layer: why a survivor bot did what it did. Data comes from pose.nut's
// BotAICapture (5 Hz per bot, changed parts only) via recording.py and ReplayChunks.decisions.
// 3D: script route, native MOVE target, local steering, escape route/goal, team goal.
// Panel (drawer tab 决策): team task, legs arbitration, route search, escape, tree nodes.
// Plain-language reasons for the labels (raw codes stay in the panel).
const BAI_GOAL = {gascan:'取油桶', pour:'灌油', pickup:'拿补给', rescue:'救倒地队友', defib:'电击复活', heal:'治疗', stim:'给队友用药', throw:'投掷', transfer:'递物资', trigger:'按机关', upgrade:'拿升级包', cut_tongue:'砍舌头救人', charger_melee:'近战推 Charger'};
const BAI_STAGE = {approaching:'前往', checking:'确认中', claimed:'前往', hold:'原地等待', jump:'跳跃', native_using:'使用中', releasing_throw:'投出', staging_approach:'送到灌油点旁', staging_drop:'放下待灌', using:'使用中', verifying_effect:'确认效果', waiting_for_cover:'等队友掩护', waiting_for_range:'先躲避，暂缓', waiting_for_safety:'等危险过去', waiting_for_tank:'等 Tank 离开'};
const BAI_FORM = {objective_worker:'搬运中，护卫跟随', objective_escort:'护送搬运者', team_progress:'跟队推进', revive_cover:'掩护救人', defib_escort:'掩护电击', pin_support:'支援被控队友', crowd_support:'支援被围队友', human_cover:'跟随玩家'};
const BAI_OWNER = {navigation:'走任务路线', goal:'执行任务', use:'去交互', survival:'躲避危险', formation:'编队站位', platform:'乘平台', travel:'推进', combat:'战斗走位'};
const BAI_REASON = {boss_escape_route:'沿躲 Tank 路线', local_steering:'局部绕障', task_native_route:'按原生寻路', no_predicted_attack:'无威胁，直接走', interaction_pending:'等交互就绪', nav_search_pending:'正在寻路', checked_route_native:'路线已校验', nav_traverse:'跨越地形', native_detour_traversal:'绕路', nav_query_route:'查询路线', native_assist_steer:'辅助转向', native_assist_jump:'辅助跳跃', airborne:'空中', wait_for_rear:'等后面的队友', vertical_step:'上下台阶', finite_horde:'尸潮有限，继续推进', cover_escaping_team:'掩护撤退的队友', ledge_rescue_cover:'掩护拉挂边', yield_escape_lane:'让出逃生通道', ground_hazard:'避开地面危险', acid_jump:'跳出酸液', checkpoint:'去安全屋', urgent_assignment:'紧急任务', witch_crown:'秒 Witch', witch_left_corridor:'绕开 Witch', rock_release_blind:'躲石头', charge_side_blind:'侧闪 Charger', critical_attack:'躲致命攻击'};
const baiNum = value => Number(Number(value ?? 0).toFixed(1));
const baiForm = (record, name) => { const form = record.t?.form; if (!form) return ''; return (BAI_FORM[form.why] || form.why) + (form.to == null ? '' : form.to === record.u ? '（领队）' : ' → ' + name(form.to)); };
// Why the bot is going where it is going, in one line. `name` turns a target reference into text.
function baiWhy(record, name) {
	const legs = record.m || {}, team = record.t || {}, escape = record.v || {}, owner = legs.owner;
	const goal = team.goal || team.as, reason = BAI_REASON[legs.reason] || legs.reason || '';
	const goalWhy = () => {
		let text = (BAI_GOAL[goal.k] || goal.k) + (goal.tg != null ? ' ' + name(goal.tg) : '') + (goal.st ? ' · ' + (BAI_STAGE[goal.st] || goal.st) : '');
		const bids = team.bids || [], mine = team.as?.s ?? bids[0]?.[2], other = bids.find(bid => bid[0] !== goal.k || JSON.stringify(bid[1]) !== JSON.stringify(goal.tg));
		if (mine != null && other) text += `（分 ${baiNum(mine)}，次选${BAI_GOAL[other[0]] || other[0]} ${baiNum(other[2])}）`;
		return text;
	};
	if (owner === 'survival') return '躲避 · ' + reason + (escape.field ? ` · Tank 约 ${baiNum(escape.field.eta)} 秒到` : '');
	if (owner === 'formation' && team.form) return baiForm(record, name) + (legs.reason === 'wait_for_rear' ? ' · 等后面的队友' : '');
	if (goal && (owner === 'navigation' || owner === 'goal' || owner === 'use' || owner === 'travel')) return goalWhy();
	if (!owner) return goal ? goalWhy() : baiForm(record, name);
	return (BAI_OWNER[owner] || owner) + (reason ? ' · ' + reason : '');
}
globalThis.ReplayBotAI = class {
	constructor(manifest, ui, camera) {
		this.ui = ui; this.camera = camera; this.meta = manifest.botai || null; this.available = !!this.meta;
		this.buffer = new ReplayLineBuffer(); this.selected = null; this.shown = null; this.hideFailed = true;
		$('botaiRow').hidden = !this.available; $('botaiTab').hidden = !this.available;
		if (!this.available) { if ($('drawer').classList.contains('bt')) document.querySelector('.tabs [data-tab=events]')?.click(); $('botaiPanel').replaceChildren(); return; }
		const paths = this.meta.paths; this.nodes = paths.map((path, id) => ({id, path, name:path.split('/').at(-1), depth:path.split('/').length - 1, order:1e6 + id, kind:''}));
		(this.meta.tree || []).forEach(([id, kind], order) => { if (this.nodes[id]) { this.nodes[id].order = order; this.nodes[id].kind = kind; } });
		$('botaiPanel').onclick = event => {
			const chip = event.target.closest('[data-bot]'); if (chip) { this.selected = Number(chip.dataset.bot); this.camera.followActor(this.selected, 650); this.shown = null; hooks.invalidate(); return; }
			if (event.target.closest('[data-toggle=failed]')) { this.hideFailed = !this.hideFailed; this.shown = null; hooks.invalidate(); }
		};
	}
	// A target reference as short text: survivors by name (userids too), objects by #id.
	refName(ref) {
		if (ref == null) return '';
		if (typeof ref === 'number') return this.ui.bots.find(bot => bot.userid === ref)?.name || String(ref);
		if (typeof ref === 'object' && 'id' in ref) { const actor = this.ui.actorById.get(ref.id), cls = String(actor?.classname || ''); if (actor?.name) return actor.name; if (replayTypes[actor?.type]) return replayTypes[actor.type][0]; return (cls === 'weapon_gascan' || cls === 'point_prop_use_target' || !cls ? '' : cls.replace(/^weapon_/, '').replace(/_spawn$/, '') + ' ') + '#' + ref.id; }
		return String(ref);
	}
	recordFor(frame, actorId) { return frame.botai?.find(record => record.e === actorId) || null; }
	botColor(actorId) { return replayRgb(this.ui.actorById.get(actorId)?.color || '#a8cad8'); }

	// ---- 3D -------------------------------------------------------------------------
	draw(frame, states, eye) {
		const out = this.buffer; out.reset(); if (!frame.botai) return out.view();
		const followed = this.camera.follow, single = typeof followed === 'number' && frame.botai.some(record => record.e === followed);
		for (const record of frame.botai) {
			const state = states.get(record.e); if (!state?.origin) continue;
			const focus = !single || record.e === followed; if (single && !focus) continue;
			this.drawBot(out, record, state, eye, this.botColor(record.e), !single || focus);
		}
		return out.view();
	}
	drawBot(out, record, state, eye, tone, detail) {
		const lift = p => p && [p[0], p[1], p[2] + 6], body = lift(state.origin), color = (rgb, a) => [rgb[0], rgb[1], rgb[2], a];
		const width = p => Math.max(.9, Math.hypot(p[0] - eye[0], p[1] - eye[1], p[2] - eye[2]) * .0011);
		const seg = (a, b, c, scale = 1) => { if (a && b) ReplayScene.quadLine(out, a, b, width(a) * scale, c, c, eye); };
		const dashed = (a, b, c) => { if (!a || !b) return; const length = Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]), steps = Math.max(1, Math.floor(length / 24)); for (let i = 0; i < steps; i += 2) { const f0 = i / steps, f1 = Math.min(1, (i + 1) / steps); seg(a.map((v, k) => v + (b[k] - v) * f0), a.map((v, k) => v + (b[k] - v) * f1), c, .8); } };
		const ring = (p, radius, c) => { if (!p) return; for (let i = 0; i < 20; i++) { const a0 = i * Math.PI / 10, a1 = (i + 1) * Math.PI / 10; seg([p[0] + Math.cos(a0) * radius, p[1] + Math.sin(a0) * radius, p[2]], [p[0] + Math.cos(a1) * radius, p[1] + Math.sin(a1) * radius, p[2]], c, .8); } };
		const post = (p, height, c) => { if (p) seg(p, [p[0], p[1], p[2] + height], c); };
		const diamond = (p, size, c) => { if (!p) return; const top = [p[0], p[1], p[2] + 40]; for (const [dx, dy] of [[1, 0], [0, 1], [-1, 0], [0, -1]]) { seg([top[0] + dx * size, top[1] + dy * size, top[2]], top.map((v, k) => k === 2 ? v + size : v), c); seg([top[0] + dx * size, top[1] + dy * size, top[2]], top.map((v, k) => k === 2 ? v - size : v), c); } post(p, 40 - size, c); };
		const route = record.r, legs = record.m || {}, escape = record.v || {}, team = record.t || {};
		if (route?.p?.length) {
			const points = route.p.map(point => lift(point)), current = route.i - route.o;
			// A task route the bot is not on (escape/survival or a use move owns the legs; c6m3 field9:
			// all samples > 300 u off-route) is drawn faint, so it is not read as the path being walked.
			let off = Infinity; for (let k = 1; k < points.length; k++) { const a = points[k - 1], b = points[k], ex = b[0] - a[0], ey = b[1] - a[1], l2 = ex * ex + ey * ey, f = l2 ? Math.max(0, Math.min(1, ((body[0] - a[0]) * ex + (body[1] - a[1]) * ey) / l2)) : 0; off = Math.min(off, Math.hypot(body[0] - a[0] - ex * f, body[1] - a[1] - ey * f)); }
			const faint = off > 150 ? .3 : 1;
			for (let k = 1; k < points.length; k++) {
				const traverse = route.p[k][3] >= 4, passed = k <= current;
				seg(points[k - 1], points[k], traverse ? [1, .62, .2, (passed ? .25 : .95) * faint] : color(tone, (passed ? .22 : .9) * faint));
			}
			if (current >= 0 && current < points.length && faint === 1) { seg(body, points[current], color(tone, .9), .7); ring(points[current], 10, [1, 1, 1, .95]); }
			if (route.g) { post(lift(route.g), 64, color(tone, .95)); ring(lift(route.g), 16, color(tone, .95)); }
		}
		if (detail && route?.qp?.length) { const query = route.qp.map(point => lift(point)); for (let k = 1; k < query.length; k++) dashed(query[k - 1], query[k], [.75, .78, .85, .7]); }
		if (route?.rej?.[0] && route.rej[1]) { const a = lift(route.rej[0]), b = lift(route.rej[1]), mid = a.map((v, k) => (v + b[k]) / 2); seg(a, b, [1, .2, .25, .95], 1.4); seg([mid[0] - 10, mid[1] - 10, mid[2] + 10], [mid[0] + 10, mid[1] + 10, mid[2] - 10], [1, .2, .25, 1], 1.4); seg([mid[0] - 10, mid[1] + 10, mid[2] + 10], [mid[0] + 10, mid[1] - 10, mid[2] - 10], [1, .2, .25, 1], 1.4); }
		for (const edge of route?.blk || []) if (edge?.[0] && edge[1]) seg(lift(edge[0]), lift(edge[1]), [1, .55, .1, .95], 1.3);
		if (legs.native?.at) { const target = lift(legs.native.at); dashed(body, target, [1, .86, .25, .75]); diamond(target, 9, [1, .86, .25, 1]); }
		if (detail && legs.wp && legs.mode === 'vector') ring(lift(legs.wp), 7, [.4, .95, 1, .95]);
		if (legs.choice) { const end = lift(legs.choice); seg(body, end, [.35, .95, 1, 1], 1.3); const dx = end[0] - body[0], dy = end[1] - body[1], d = Math.hypot(dx, dy) || 1, ux = dx / d, uy = dy / d; seg(end, [end[0] - ux * 10 - uy * 6, end[1] - uy * 10 + ux * 6, end[2]], [.35, .95, 1, 1], 1.3); seg(end, [end[0] - ux * 10 + uy * 6, end[1] - uy * 10 - ux * 6, end[2]], [.35, .95, 1, 1], 1.3); }
		if (detail) for (const tried of legs.tried || []) if (tried && (!legs.choice || tried.some((v, k) => v !== legs.choice[k]))) seg(body, lift(tried), [.6, .6, .65, .45], .6);
		if (escape.route?.p?.length) { const points = escape.route.p.map(point => lift(point)); for (let k = 1; k < points.length; k++) seg(points[k - 1], points[k], [1, .3, .3, k <= escape.route.i ? .3 : .95]); }
		if (escape.route?.g) { post(lift(escape.route.g), 80, [1, .3, .3, 1]); ring(lift(escape.route.g), 20, [1, .3, .3, 1]); }
		if (escape.field?.g) { post(lift(escape.field.g), 96, [1, .35, .9, 1]); ring(lift(escape.field.g), 26, [1, .35, .9, 1]); }
		const goal = team.goal?.p || team.as?.p;
		if (detail && goal) { const flag = lift(goal); dashed(body, flag, [.45, 1, .55, .6]); post(flag, 56, [.45, 1, .55, 1]); seg([flag[0], flag[1], flag[2] + 56], [flag[0] + 16, flag[1], flag[2] + 48], [.45, 1, .55, 1]); seg([flag[0] + 16, flag[1], flag[2] + 48], [flag[0], flag[1], flag[2] + 40], [.45, 1, .55, 1]); }
	}

	// ---- Labels ---------------------------------------------------------------------
	// Why the bot goes there, written at the destinations only: task route end (goal + target), native
	// MOVE target (legs owner + reason), escape goal (field/route), formation (at the bot). Labels closer
	// than a box to an earlier (more important) one are dropped; far ones fade.
	drawLabels(g, frame, states, eye, project, scale) {
		if (!frame.botai) return;
		const followed = this.camera.follow, single = typeof followed === 'number' && frame.botai.some(record => record.e === followed), items = [];
		const name = ref => this.refName(ref);
		const near = (a, b, d = 60) => a && b && Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]) < d;
		for (const record of frame.botai) {
			const state = states.get(record.e); if (!state?.origin || single && record.e !== followed) continue;
			const tone = this.ui.actorById.get(record.e)?.color || '#a8cad8', team = record.t || {}, legs = record.m || {}, route = record.r, escape = record.v || {}, bot = this.ui.actorById.get(record.e)?.name || '';
			const goal = team.goal || team.as, goalText = goal ? (BAI_GOAL[goal.k] || goal.k) + (goal.tg != null ? ' ' + name(goal.tg) : '') + (goal.st ? ' · ' + (BAI_STAGE[goal.st] || goal.st) : '') : '';
			const moveText = baiWhy(record, name);
			const end = route?.g || route?.p?.at(-1);
			// The route end carries the full "why" when the task route is what the legs follow; otherwise
			// the MOVE target does (formation, escape, platform...) and the route end keeps the goal.
			const routeOwned = !legs.owner || legs.owner === 'navigation' || legs.owner === 'goal' || legs.owner === 'use' || legs.owner === 'travel';
			if (end) items.push({p:end, pri:3, color:tone, text:(single ? '' : bot + '：') + ((routeOwned ? moveText || goalText : goalText) || '路线 ' + (route.st || ''))});
			if (!routeOwned && legs.native?.at && !near(legs.native.at, end)) items.push({p:legs.native.at, pri:3.5, color:'#ffd95a', text:(single ? '' : bot + '：') + (moveText || legs.native.mode || '')});
			const field = escape.field, escapeGoal = field?.g || escape.route?.g;
			if (escapeGoal) items.push({p:escapeGoal, pri:4, color:'#ff6b8a', text:field ? `躲 Tank：往这跑，退路还能保持 ${baiNum(field.freedom)} 秒 · Tank 约 ${baiNum(field.eta)} 秒追到${field.chased ? ' · 正被追' : ''}` : '躲避路线终点'});
			if (single && field?.cv && !near(field.cv, escapeGoal)) items.push({p:field.cv, pri:1.5, color:'#ff9fd0', text:'Tank 扔石头时躲这里（挡视线）'});
			if (team.goal?.p && !near(team.goal.p, end, 160) && !near(team.goal.p, legs.native?.at)) items.push({p:team.goal.p, pri:2, color:'#74f08c', text:goalText});
			if (single && team.form) items.push({p:[state.origin[0], state.origin[1], state.origin[2] + 96], pri:1, color:'#cfe3ff', text:'编队 · ' + baiForm(record, name)});
			if (single && legs.local && (legs.local.danger || legs.local.pursuit || legs.local.hunt)) items.push({p:[state.origin[0], state.origin[1], state.origin[2] + 116], pri:1, color:'#7fe8ff', text:'转向 · ' + [legs.local.danger ? '危险规避' : '', legs.local.pursuit ? '被追' : '', legs.local.hunt ? 'hunt ' + legs.local.hunt : ''].filter(Boolean).join(' · ')});
		}
		items.sort((a, b) => b.pri - a.pri); const placed = [];
		g.font = `600 ${11.5 * scale}px "Segoe UI",system-ui,sans-serif`; g.textAlign = 'left'; g.textBaseline = 'middle';
		for (const item of items) {
			if (!item.text) continue; const point = project([item.p[0], item.p[1], item.p[2] + 70]); if (!point || point[2] > 1) continue;
			const text = item.text.length > 48 ? item.text.slice(0, 47) + '…' : item.text, w = g.measureText(text).width + 12 * scale, h = 18 * scale, x = point[0] + 8 * scale, y = point[1];
			if (x > g.canvas.width || y < 0 || y > g.canvas.height || x + w < 0) continue;
			if (placed.some(([px, py, pw]) => x < px + pw && px < x + w && Math.abs(py - y) < h)) continue; placed.push([x, y, w]);
			const distance = Math.hypot(item.p[0] - eye[0], item.p[1] - eye[1], item.p[2] - eye[2]); g.globalAlpha = clamp(1.6 - distance / 2500, .35, 1);
			g.fillStyle = 'rgba(8,12,20,.72)'; g.beginPath(); g.roundRect(x, y - h / 2, w, h, 5 * scale); g.fill();
			g.fillStyle = item.color; g.fillRect(x, y - h / 2 + 3 * scale, 2.5 * scale, h - 6 * scale);
			g.fillStyle = '#eef3fa'; g.fillText(text, x + 7 * scale, y + .5 * scale);
		}
		g.globalAlpha = 1;
	}

	// ---- Panel ----------------------------------------------------------------------
	panel(frame, time) {
		if (!this.available || !$('drawer').classList.contains('bt') || $('drawer').classList.contains('closed')) return;
		const follow = this.camera.follow, bots = this.ui.bots, ids = new Set(bots.map(bot => bot.id));
		if (ids.has(follow)) this.selected = follow; if (!ids.has(this.selected)) this.selected = bots[0]?.id;
		const record = this.recordFor(frame, this.selected), key = [this.selected, record, this.hideFailed, Math.floor(time * 2)].map(String).join('|');
		if (record === this.shownRecord && key === this.shown) return;
		// Records change with every 0.1 s sample while playing; rebuild the DOM at most ~5 times a second.
		const now = performance.now(); if (now - (this.builtAt || 0) < 200) { clearTimeout(this.retry); this.retry = setTimeout(() => hooks.invalidate(), 210); return; }
		this.builtAt = now; this.shown = key; this.shownRecord = record;
		const esc = value => String(value ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;'}[c]));
		const node = id => this.nodes[id] || {name:'#' + id, path:'#' + id}, ref = value => value == null ? '—' : typeof value === 'object' && 'id' in value ? (this.ui.actorById.get(value.id)?.name || replayTypes[this.ui.actorById.get(value.id)?.type]?.[0] || this.ui.actorById.get(value.id)?.classname || '实体') + ' #' + value.id : Array.isArray(value) ? value.map(Math.round).join(', ') : esc(value);
		const num = (value, digits = 1) => value == null ? '—' : String(Number(Number(value).toFixed(digits)));
		const ago = at => at == null ? '' : (time - at).toFixed(1) + ' 秒前', point = p => p ? '(' + p.map(Math.round).join(', ') + ')' : '—';
		const row = (label, value, cls = '') => `<div class="kv ${cls}"><span>${label}</span><b>${value}</b></div>`;
		const chips = bots.map(bot => `<span class="chip${bot.id === this.selected ? ' on' : ''}" data-bot="${bot.id}"><i class="dot" style="--c:${bot.color}"></i>${esc(bot.name)}</span>`).join('');
		let html = `<div class="bai-bots">${chips}</div>`;
		if (!record) { $('botaiPanel').innerHTML = html + '<p class="note">此刻没有这名生还者的 BotAI 记录（不是 BotAI 控制的 bot，或尚未采样）。</p>'; return; }
		html += `<p class="note">决策 #${record.g} · 采样 ${ago(record.sampled)}（每个 bot 约 5 次/秒，仅记录变化的部分）</p>`;
		const team = record.t || {}, legs = record.m || {}, route = record.r, escape = record.v || {};
		const why = baiWhy(record, value => this.refName(value)); if (why) html += row('为什么', esc(why));
		html += '<h4>团队任务</h4>';
		html += row('分配', team.as ? `${esc(team.as.k)} · ${ref(team.as.tg)} · 分数 ${num(team.as.s)}${team.as.pr != null ? ' <small>(优先级 ' + num(team.as.pr, 0) + ')</small>' : ''}` : '无');
		html += row('当前目标', team.goal ? `${esc(team.goal.k)} · ${esc(team.goal.st)} · ${ref(team.goal.tg)}${team.goal.at != null ? ' · 已进行 ' + Math.max(0, time - team.goal.at).toFixed(1) + ' 秒' : ''}${team.goal.why ? '<br><small>等待原因 ' + esc(team.goal.why) + (team.goal.by != null ? ' · ' + ref(team.goal.by) : '') + '</small>' : ''}${team.goal.use ? '<br><small>使用计划 ' + esc(team.goal.use) + '</small>' : ''}` : '无');
		if (team.bids?.length) html += row('出价', team.bids.map(bid => `${esc(bid[0])} ${ref(bid[1])} <small>${num(bid[2])}</small>`).join('<br>'));
		if (team.form) html += row('编队', `${esc(BAI_FORM[team.form.why] || team.form.why)} <small>${esc(team.form.why)}</small> → ${esc(this.refName(team.form.to))}`);
		if (team.w) {
			// Witch team plan (recorded from 2026-11-18): pass / pass candidate / close kill / volley / hold clock.
			const w = team.w, parts = [];
			if (w.pass != null) parts.push(`绕行 ${ref(w.pass)}${w.pm ? '（本 bot 参与）' : ''}`);
			if (w.cand != null) parts.push(`绕行候选 ${ref(w.cand)}${w.try ? ' · 已试 ' + esc(w.try) : ''}${w.walk ? ' · 步行绕过' : ''}`);
			if (w.as) parts.push(`近身击杀 · ${esc({gather:'集合', approach:'接近', strike:'出手'}[w.as.ph] || w.as.ph)} · ${w.as.slot === 'slot0' ? '霰弹枪' : '近战'}${w.as.me ? '（本 bot 参与）' : ''}`);
			if (w.vo) parts.push(`齐射 · ${w.vo.rd ? '开火' : '等待就位'} · ${w.vo.n} 人${w.vo.me ? '（含本 bot）' : ''}`);
			if (w.held != null) parts.push(`已被拦 ${w.held} 秒${w.cf ? ' · 近身击杀已放弃' : ''}`);
			if (w.ign) parts.push('暂时忽略（超时放行）');
			html += row('Witch 计划', parts.join('<br>') || '—');
		}
		html += '<h4>腿部（移动）</h4>';
		html += row('胜出请求', legs.mode ? `${esc(legs.owner)} · ${esc(legs.mode)}${legs.reason ? ' · ' + esc(legs.reason) : ''}` : '无移动请求');
		if (legs.src != null) html += row('来自节点', `<span title="${esc(node(legs.src).path)}">${esc(node(legs.src).name)}</span>`);
		if (legs.pos) html += row('任务终点', point(legs.pos)); if (legs.wp) html += row('路点', point(legs.wp)); if (legs.nt) html += row('原生前瞻点', point(legs.nt));
		html += row('原生 MOVE', legs.native ? `${esc(legs.native.mode)} ${legs.native.at ? point(legs.native.at) : ref(legs.native.target)} · 发出于 ${ago(legs.native.sent)}` : '无');
		if (legs.local) html += row('局部转向', [legs.local.danger ? '危险规避' : '任务转向', legs.local.pursuit ? '被追' : '', legs.local.hunt ? 'hunt ' + esc(legs.local.hunt) : '', legs.local.standoff ? '对峙' : '', legs.local.recovery ? '恢复绕行' : ''].filter(Boolean).join(' · ') + (legs.choice ? ' · 选中方向 ' + point(legs.choice) : ' · 无可行方向'));
		if (legs.patch) html += row('地面危险', '路线前方有酸液/火焰');
		html += '<h4>寻路</h4>';
		const status = {planned:'已规划', searching:'搜索中', no_nav_path:'无导航路径', no_survivor_nav_path:'生还者不可通行', nav_search_limit:'搜索超限'};
		if (!route) html += row('脚本路线', '无');
		else {
			html += row('状态', `${status[route.st] || esc(route.st)} · 第 ${route.i}/${route.n} 点${route.f ? ' · 失败 ' + route.f + ' 次' : ''}`);
			html += row('路线键', ref(route.key));
			if (route.x != null || route.sx != null) html += row('搜索', `${route.x != null ? '展开 ' + route.x + ' 区域' : ''}${route.sx != null ? ' 进行中：展开 ' + route.sx + '，待选 ' + route.so : ''}`);
			if (route.rej) html += row('拒绝原生路径', '原生寻路经过生还者不可走的连接（红叉），改用脚本搜索', 'warn');
			if (route.wd) html += row('步行绕行', '用步行通道替代原生跳跃捷径');
			if (route.blk?.length) html += row('阻塞连接', route.blk.length + ' 条（橙线）', 'warn');
			if (route.qp) html += row('原生查询路线', route.qp.length + ' 点（灰色虚线）');
			if (route.unreach) html += row('不可达', '反向搜索证明目标不可达', 'warn');
			html += row('更新', ago(record.since?.r));
		}
		html += '<h4>逃生</h4>';
		html += row('需要逃生', escape.req ? '是' : '否', escape.req ? 'warn' : '');
		if (escape.intent) html += row('逃生意图', '有');
		if (escape.route) html += row('逃生路线', `${escape.route.field ? 'Tank 场路线' : '导航逃生路线'} · 第 ${escape.route.i}/${escape.route.p?.length ?? 0} 点 · 终点 ${point(escape.route.g)}`);
		if (escape.field) html += row('Tank 场', `自由度 ${num(escape.field.freedom, 2)} · ETA ${num(escape.field.eta, 2)} 秒${escape.field.chased ? ' · 被追' : ''}${escape.field.moving ? ' · 移动中' : ''}`);
		html += '<h4>请求仲裁</h4>';
		const channels = {move:'移动', view:'视角', weapon:'武器', buttons:'按键', buttonBlock:'按键屏蔽', freeze:'冻结', medicalGuard:'医疗保护', interruptRevive:'中断救援', teleport:'传送'};
		const requests = (record.q || []).slice().sort((a, b) => a[0] === b[0] ? b[3] - a[3] : a[0] < b[0] ? -1 : 1);
		html += '<div class="bai-req">' + (requests.length ? requests.map(([channel, source, owner, priority, detail, won]) => `<div class="${won ? 'won' : ''}"><span>${won ? '✔' : ''}</span><span>${esc(channels[channel] || channel)}</span><span>${esc(owner)} · ${num(priority)}</span><span title="${esc(node(source).path)}">${esc(detail || node(source).name)}</span></div>`).join('') : '<p class="note">本次决策没有请求</p>') + '</div>';
		const visited = (record.n || []).map(code => ({...node(code >> 2), status:code & 3})), aborted = (record.aborted || []).map(id => ({...node(id), status:4}));
		const rows = [...visited, ...aborted].filter(item => !this.hideFailed || item.status !== 1).sort((a, b) => a.order - b.order);
		const label = ['成功', '失败', '运行中', '其它', '中止'];
		html += `<h4>行为树 <span class="chip mini" data-toggle="failed">${this.hideFailed ? '显示失败节点' : '隐藏失败节点'}</span></h4>`;
		html += `<p class="note">本次决策执行了 ${visited.length} 个节点（运行中 ${visited.filter(item => item.status === 2).length}，失败 ${visited.filter(item => item.status === 1).length}）${aborted.length ? '，上次采样后中止 ' + aborted.length + ' 个' : ''}。</p>`;
		html += '<div class="bai-tree">' + rows.map(item => `<div class="s${item.status}" style="padding-left:${item.depth * 9 + 4}px" title="${esc(item.path)}"><i></i>${esc(item.name)}<small>${label[item.status]}</small></div>`).join('') + '</div>';
		$('botaiPanel').innerHTML = html;
	}
};
