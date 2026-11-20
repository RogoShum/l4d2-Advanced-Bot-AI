'use strict';

globalThis.SourceSprite = {
	async load(library, path) {
		const materialPath = path.replace(/^materials\//,'').replace(/\.(vmt|spr)$/,''), original = await library.material(materialPath);
		if (!original.texture) throw Error('缺少精灵材质纹理：' + path);
		const material = {...original, shader:'unlitgeneric', values:{...original.values,$nocull:'1',$translucent:'1'}};
		if ([3,5,9].includes(Number(original.values.$spriterendermode))) material.values.$additive = '1';
		const width = original.texture.sourceWidth, height = original.texture.sourceHeight, identity = [1,0,0,0,0,1,0,0,0,0,1,0], bones = [{id:0,name:'sprite',parent:-1,position:[0,0,0],quaternion:[0,0,0,1],inverse:identity,proc:0}];
		const vertices = new Float32Array([-width/2,0,-height/2,width/2,0,-height/2,width/2,0,height/2,-width/2,0,height/2]), weights = new Float32Array([1,0,0,1,0,0,1,0,0,1,0,0]);
		return {path,bones,used:[0],groups:[{vertices,normals:new Float32Array([0,-1,0,0,-1,0,0,-1,0,0,-1,0]),uv:new Float32Array([0,1,1,1,1,0,0,0]),weights,bones:new Uint16Array(12),indices:new Uint16Array([0,1,2,0,2,3]),materialIndex:0,lod:0}],materials:[material],skins:[],replacements:{},attachments:[],physics:[],collision:null,hitboxSets:[],animation:{bones,sequences:[],poseParameters:[],includes:[]},sprite:{width,height,orientation:original.values.$spriteorientation || 'vp_parallel'}};
	},
	matrix(model, actor, eye, view) {
		const source = actor.matrices, origin = [source[12],source[13],source[14]], normalize=ReplayRenderer.normalize, scale = Math.hypot(source[0],source[1],source[2])*(actor.sprite?.scale ?? 1), orientation = model.sprite.orientation;
		if (orientation==='oriented') { const matrix=source.slice();for(let i=0;i<12;i++)matrix[i]*=actor.sprite?.scale ?? 1;return matrix; }
		const facing = normalize(eye.map((v,k)=>v-origin[k])); let right,up;
		if (orientation==='vp_parallel_upright' || orientation==='facing_upright') { right=normalize([-facing[1],facing[0],0]);up=[0,0,1]; }
		else { right=normalize([view[0],view[4],view[8]]);up=normalize([view[1],view[5],view[9]]); }
		if (orientation==='vp_parallel_oriented') { const angle=(actor.sprite?.roll || 0)*Math.PI/180,c=Math.cos(angle),s=Math.sin(angle),r=right;right=right.map((v,k)=>v*c+up[k]*s);up=up.map((v,k)=>v*c-r[k]*s); }
		return new Float32Array([...right.map(v=>v*scale),0,...facing.map(v=>-v*scale),0,...up.map(v=>v*scale),0,...origin,1]);
	},
	beam(model, actor, eye, time) {
		const beam=actor.beam,a=beam.start,b=beam.end;if(!a||!b)return null;
		const controls=beam.type===4?beam.points:[a,b];if(!controls||controls.length<2)return null;const positions=[];
		for(let i=0;i<controls.length-1;i++){const p0=controls[Math.max(0,i-1)],p1=controls[i],p2=controls[i+1],p3=controls[Math.min(controls.length-1,i+2)],steps=beam.type===4?Math.max(2,Math.min(128,Math.ceil(Math.hypot(...p2.map((v,k)=>v-p1[k]))*.075)+3)):2;
			for(let j=0;j<steps-1;j++){const t=j/(steps-1);positions.push(beam.type===4?p1.map((v,k)=>.5*(2*v+(-p0[k]+p2[k])*t+(2*p0[k]-5*v+4*p2[k]-p3[k])*t*t+(-p0[k]+3*v-3*p2[k]+p3[k])*t*t*t)):p1);}}
		positions.push(controls[controls.length-1]);const lengths=[0];for(let i=1;i<positions.length;i++)lengths.push(lengths[i-1]+Math.hypot(...positions[i].map((v,k)=>v-positions[i-1][k])));const length=lengths[lengths.length-1];if(!length)return null;
		const fade=Math.max(.000001,Math.min(1,(beam.fade || 0)/length)),scroll=time*(beam.speed || 0)%1,rows=positions.map((position,i)=>{const t=lengths[i]/length;let alpha=1;if((beam.flags&192)===192)alpha=t<.5?2*t/fade:2*(1-t/fade);else if(beam.flags&64)alpha=t/fade;else if(beam.flags&128)alpha=1-t/fade;return {position,width:beam.width+((beam.endWidth ?? beam.width)-beam.width)*t,texture:scroll+(beam.flags&512?t:lengths[i]*.01),alpha:Math.max(0,Math.min(1,alpha))};});
		return this.ribbon(model,actor,rows,eye,beam.frame || 0);
	},
	trail(model,actor,eye,time) {
		const trail=actor.trail,points=trail.points;if(!(trail.life>0)||!points?.length)return null;const samples=[];model.sprite.trails ||= new WeakMap();let distances=model.sprite.trails.get(points);
		if(!distances){distances=new Float32Array(points.length/4);for(let i=1;i<distances.length;i++)distances[i]=distances[i-1]+Math.hypot(points[i*4+1]-points[i*4-3],points[i*4+2]-points[i*4-2],points[i*4+3]-points[i*4-1]);model.sprite.trails.set(points,distances);}
		let low=0,high=points.length/4;while(low<high){const mid=(low+high)>>1;if(points[mid*4]<=time)low=mid+1;else high=mid;}const upper=low;low=0;high=upper;while(low<high){const mid=(low+high)>>1;if(points[mid*4]<time-trail.life)low=mid+1;else high=mid;}
		const start=Math.max(low,upper-255),begin=time-trail.life;if(start===low&&low>0&&low<distances.length){const t=(begin-points[(low-1)*4])/(points[low*4]-points[(low-1)*4]);samples.push({t:begin,position:[1,2,3].map(k=>points[(low-1)*4+k]+(points[low*4+k]-points[(low-1)*4+k])*t),distance:distances[low-1]+(distances[low]-distances[low-1])*t});}
		for(let i=start;i<upper;i++)samples.push({t:points[i*4],position:Array.from(points.subarray(i*4+1,i*4+4)),distance:distances[i]});
		const position=Array.from(actor.matrices.slice(12,15)),last=samples[samples.length-1];samples.push({t:time,position,distance:last?last.distance+Math.hypot(...position.map((v,k)=>v-last.position[k])):0});if(samples.length<2)return null;
		const rows=samples.map(sample=>{const life=Math.max(0,Math.min(1,1-(time-sample.t)/trail.life)),end=trail.endWidth>=0?trail.endWidth:trail.startWidth;return {position:sample.position,width:end+(trail.startWidth-end)*life,texture:sample.distance*trail.textureResolution,alpha:Math.min(life,trail.fade>0?(sample.distance-samples[0].distance)/trail.fade:1)};});
		return this.ribbon(model,actor,rows,eye,actor.sprite?.frame || 0);
	},
	ribbon(model,actor,rows,eye,frame) {
		const corners=rows.map((row,i)=>{const previous=rows[Math.max(0,i-1)].position,next=rows[Math.min(rows.length-1,i+1)].position,direction=next.map((v,k)=>v-previous[k]),view=eye.map((v,k)=>v-row.position[k]),side=ReplayRenderer.normalize([direction[1]*view[2]-direction[2]*view[1],direction[2]*view[0]-direction[0]*view[2],direction[0]*view[1]-direction[1]*view[0]]);return [-1,1].map(sign=>[...row.position.map((v,k)=>v+side[k]*row.width*.5*sign),(sign+1)/2,row.texture,...(actor.tint || [1,1,1]).map(v=>v*(actor.beam?.hdrScale ?? 1)),(actor.alpha ?? 1)*row.alpha]);});
		const vertices=new Float32Array((rows.length-1)*54);let at=0;for(let i=0;i<rows.length-1;i++)for(const [row,side] of [[i,0],[i+1,0],[i+1,1],[i,0],[i+1,1],[i,1]]){vertices.set(corners[row][side],at);at+=9;}
		return {vertices,material:model.materials[0],frame,additive:[3,5,9].includes(actor.renderMode)};
	}
};
