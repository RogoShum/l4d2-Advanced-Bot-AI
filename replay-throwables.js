'use strict';
globalThis.ReplayThrowables = class {
	static isBiled(state, frame, time) {
		if (state.status?.bileUntil != null) return state.status.bileUntil > time;
		if (state.life !== 0 || (state.classname !== 'infected' && state.classname !== 'witch')) return false;
		return frame.throwables.some(effect => effect.kind === 'bile' && time >= effect.t && time < effect.until && effect.nearby.includes(state.id));
	}
	static overlays(scene,time) {
		const frame=scene.frame,glow=[],soft=[];
		const batch=(kind,origin,id,age,count,vertices,additive=false)=>(additive?glow:soft).push({kind,origin,id,age,count,verticesPerParticle:vertices,additive,glow:+additive});
		for(const state of frame.entities){
			if(state.classname!=='pipe_bomb_projectile'||!state.origin||time<Math.fround(state.start)||frame.throwables.some(e=>e.id===state.id&&time>=e.t))continue;
			const beeps=frame.pipeBeeps.filter(e=>(e.id!=null?e.id===state.id:e.entity===state.entity)&&e.t>=Math.fround(state.start)),age=Math.max(0,time-state.start),fuse=Math.max(.1,state.end-state.start);
			if(beeps.length?beeps.some(e=>time>=e.t&&time-e.t<.075):(age*(1.6+2.8*Math.min(1,age/fuse)))%1<.4)batch(0,scene.interpolated(state,time).origin,state.id,age,1,48,true);
		}
		for(const e of frame.throwables){
			const age=time-e.t;if(age<0||time>=e.until)continue;
			if(e.kind==='bile'){
				if(age<.7){batch(1,e.origin,e.id,age,1,48,true);batch(2,e.origin,e.id,age,14,48);}
				if(age>0&&age<12)batch(3,e.origin,e.id,age,5,48);
				if(age<.65)batch(4,e.origin,e.id,age,7,12);
			}else if(e.kind==='pipe'){
				if(age<.45)batch(5,e.origin,e.id,age,6,48,true);
				if(age>.08)batch(6,e.origin,e.id,age,9,216);
			}
		}
		return glow.concat(soft);
	}
};
ReplayThrowables.bileColor = [.62, 1, .22, 1.35];
ReplayThrowables.vertex = `#version 300 es
precision highp float;layout(location=0)in float vertex;uniform mat4 view;uniform vec3 origin,eye,forward;uniform float age,seed;uniform int kind;out vec4 vColour;out float vZ;
vec3 unit(vec3 v){return v/max(length(v),1.e-8);}
vec3 smoke(int i,float t){float a=seed+float(i)*2.4+.09*t,r=5.+float(11+i%4*8)*sqrt(max(t,0.));return origin+vec3(cos(a)*r+7.*t,sin(a)*r,12.+float(22+i%5*12)*t);}
void main(){int j=int(vertex),i=gl_InstanceID;float fi=float(i),r=0.,base=origin.z,phase=0.,k=age;vec3 p=origin;vec4 inner=vec4(0),outer=vec4(0);gl_Position=vec4(2,2,2,1);vColour=vec4(0);vZ=0.;
if(kind==0){p.z+=4.;r=11.;inner=vec4(2.4,.18,.08,.95);outer=vec4(1.1,.03,.01,0);}
else if(kind==1){k=age/.7;p.z+=12.+k*13.;r=14.+k*24.;inner=vec4(.47,1.05,.12,.6*(1.-k));outer=vec4(.27,.7,.05,0);base+=4.;}
else if(kind==2){k=age/.7;float a=fi*2.4+seed;p+=vec3(vec2(cos(a),sin(a))*float(12+6*(i%5))*k*3.,5.+float(58+13*(i%4))*4.*k*(1.-k));r=float(4+i%3*2);inner=vec4(.54,.79,.08,.9*(1.-k));outer=vec4(.25,.46,.04,0);base+=2.;}
else if(kind==3){float a=fi*1.257+age*.15;p+=vec3(vec2(cos(a),sin(a))*(35.+22.*sin(fi*2.1+age*.4)),19.+fi*6.+sin(age*.8+fi)*4.);r=36.+fi*5.;inner=vec4(.42,.62,.16,.23*min(age,1.-(age-1.)/11.));outer=vec4(.36,.55,.12,0);base+=4.;}
else if(kind==4){k=age/(.38+.045*fi);if(k>=1.)return;float a=seed+2.4*fi,y=a+age*(5.+fi),pitch=fi*.9+age*(10.+fi),len=float(6+i%4);p+=vec3(vec2(cos(a),sin(a))*float(38+11*(i%4))*k,7.+float(28+9*(i%4))*4.*k*(1.-k));
vec3 ax=vec3(cos(y)*cos(pitch),sin(y)*cos(pitch),sin(pitch)),w=vec3(-sin(y),cos(y),0),tip=p+len*ax-.5*w,heel=p-.55*len*ax-.8*w,left=p-.25*len*ax+2.4*w,right=p-.48*len*ax-1.8*w;
float f=min(1.,(1.-k)*4.);vec4 bright=vec4(.76,.94,.88,.9*f);if(j<6){p=j==0||j==3?tip:j==1?left:j==5?right:heel;vColour=j<3?vec4(.18,.44,.38,.83*f):bright;}
else{int t=j-6;bool end=t==1||t==2||t==4;vec3 side=unit(cross(tip-left,eye-left))*.35;p=(end?tip:left)+(t==2||t==4||t==5?side:-side);vColour=end?bright:vec4(.92,1,.97,f);}gl_Position=view*vec4(p,1);vZ=p.z;return;}
else if(kind==5){k=age/.45;float f=(1.-k)*(1.-k);base+=5.;if(i==0){p.z+=18.+32.*k;r=36.+38.*k;inner=vec4(3.2,2.3,1.1,f);outer=vec4(1.5,.52,.07,0);}else{i--;float a=seed+float(i)*2.4;p+=vec3(vec2(cos(a),sin(a))*float(23+(i%3)*12)*sqrt(k),15.+float(32+14*(i%3))*k);r=15.+float(12+i*2)*k;inner=vec4(2.2,1.03,.24,.8*f);outer=vec4(.9,.22,.03,0);}}
else if(kind==7){float strength=1.-age/.05;p+=forward*(2.+fi*3.);if(j%3==0)vColour=vec4(2.1-fi*.35,1.4-fi*.35,.65-fi*.25,strength*.7);else{float a=float(j/3+int(j%3==2))*3.14159265/12.;vec3 n=unit(eye-origin),side=unit(cross(n,abs(n.z)>.95?vec3(0,1,0):vec3(0,0,1)));p+=(side*cos(a)+cross(side,n)*sin(a))*(4.5-fi)*(.8+.2*strength);vColour=vec4(1.1,.32,.035,0);}gl_Position=view*vec4(p,1);vZ=p.z;return;}
else{float depths[9];int order[9];for(int n=0;n<9;n++){float t=age-.08-float(n%3)*.13;depths[n]=distance(eye,smoke(n,t));int m=n;while(m>0&&depths[order[m-1]]<depths[n]){order[m]=order[m-1];m--;}order[m]=n;}i=order[i];float t=age-.08-float(i%3)*.13,life=3.3+float(i%4)*.32;if(t<=0.||t>=life)return;p=smoke(i,t);r=10.+float(13+i%3*5)*sqrt(t);phase=seed+float(i)*2.4+.18*t;inner=vec4(.23,.21,.19,.74*min(1.,t/.25)*pow(1.-t/life,.8));outer=vec4(.39,.38,.36,0);base+=5.;}
bool cloud=kind==6;int stride=cloud?9:3,corner=j%stride;vColour=inner;
if(corner!=0){bool next=cloud?(corner==2||corner==5||corner==7||corner==8):corner==2;float a=float(j/stride+int(next))*6.28318531/(cloud?24.:16.),c=cos(a),s=sin(a);
vec3 n=unit(eye-p),side=length(n.xy)>0.?vec3(n.y,-n.x,0)/length(n.xy):vec3(1,0,0),up=cross(side,n);float size=r*(cloud?1.+.13*cos(3.*a+phase)+.09*sin(5.*a-phase):1.);
vec3 offset=side*c*size+up*s*(s<0.&&up.z>0.?min(size,max(0.,(p.z-base)/up.z)):size);bool shoulder=cloud&&(corner==1||corner==2||corner==3||corner==6||corner==8);p+=(shoulder?.55:1.)*offset;
float light=.25+.12*s-.08*c+.035*cos(3.*a+phase);vColour=shoulder?vec4(light+.035,light+.02,light,inner.a*.78):outer;}gl_Position=view*vec4(p,1);vZ=p.z;}`;
