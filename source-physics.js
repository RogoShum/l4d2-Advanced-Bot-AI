'use strict';

// VPHY terminal ledges; internal tree hulls are broadphase geometry.
globalThis.SourcePhysics = {
	read(bytes) {
		const d = SourceIO.view(bytes), I = at=>d.getInt32(at,true), U = at=>d.getUint16(at,true);
		if (I(0)!==16 || I(4)!==0) throw Error('PHY 文件头不支持');
		let offset = 16; const solids = [];
		for (let solid = 0; solid < I(8); solid++) {
			const size = I(offset), base = offset+32;
			if (SourceIO.text(bytes.subarray(offset+4,offset+8))!=='VPHY' || U(offset+10)!==0 || SourceIO.text(bytes.subarray(base+44,base+48))!=='IVPS') throw Error('PHY 碰撞实体格式不支持');
			const nodes = [base+I(base+32)], convexes = [];
			while (nodes.length) {
				const node = nodes.pop(), right = I(node); if (right) { nodes.push(node+right,node+28); continue; }
				const at = node+I(node+4), vertexOffset = I(at), bone = I(at+4), count = U(at+12); if (I(at+8)&3) throw Error('PHY 叶节点不是碰撞表面');
				const indices = new Uint16Array(count*3), ids = new Map(), positions = [];
				for (let i = 0; i < count; i++) for (let j = 0; j < 3; j++) { const id = U(at+20+i*16+j*4); if (!ids.has(id)) { ids.set(id,ids.size); const p = at+vertexOffset+id*16; positions.push(d.getFloat32(p,true)/.0254,d.getFloat32(p+8,true)/.0254,-d.getFloat32(p+4,true)/.0254); } indices[i*3+j] = ids.get(id); }
				convexes.push({bone,vertices:new Float32Array(positions),indices});
			}
			solids.push(convexes); offset += size+4;
		}
		const keyvalues = SourceIO.text(bytes.subarray(offset));
		const bodies = (keyvalues.match(/solid\s*\{[^}]*\}/g) || []).map(block=>SourceIO.keys(block).values).map(s=>({name:s.name,mass:Number(s.mass),volume:Number(s.volume),index:Number(s.index)}));
		return {solids,bodies};
	}
};
