module 'mock'

--------------------------------------------------------------------
local function _unpack(m)
	local tt=type(m)
	if tt=='number' then return m,m end
	if tt=='table' then  return unpack(m) end
	if tt=='function' then  return m() end
	error('????')
end

--------------------------------------------------------------------
CLASS: EffectNodeParticleSystem  ( EffectNode )
CLASS: EffectNodeParticleState   ( EffectNode )
CLASS: EffectNodeParticleEmitter ( EffectNode )
CLASS: EffectNodeParticleForce   ( EffectNode )

----------------------------------------------------------------------
--CLASS: EffectNodeParticleSystem
--------------------------------------------------------------------
EffectNodeParticleSystem :MODEL{
	Field 'blend'        :enum( EnumBlendMode );
	Field 'deck'         :asset( 'deck2d\\..*' );
	'----';
	Field 'particleLimit'    :int()  :range(0);
	Field 'spriteLimit'      :int()  :range(0);
	'----';
	Field 'syncTransform' :boolean();
}

function EffectNodeParticleSystem:__init()
	self.particleLimit = 100
	self.spriteLimit   = self.particleLimit
	self.blend = 'add'
	self.deck  = false
	self.syncTransform = false
end

function EffectNodeParticleSystem:getDefaultName()
	return 'particle'
end

function EffectNodeParticleSystem:postBuild()
	local states   = {}
	local forces   = {}
	local emitters = {}
	--build state
	local regs = {}
	for i, child in pairs( self.children ) do
		local c = child:getClassName()
		if child:isInstance( EffectNodeParticleState ) then
			table.insert( states, child )
			child:_buildState( regs )
		elseif child:isInstance( EffectNodeParticleEmitter ) then
			table.insert( emitters, child )
		elseif child:isInstance( EffectNodeParticleForce ) then
			table.insert( forces, child )
		end
	end
	
	local builtStates = {}
	for i, s in ipairs( states ) do
		local state = s.moaiParticleState
		for j, f in ipairs( forces ) do
			state:pushForce( f.moaiParticleForce )
		end
		builtStates[ i ] = state
	end

	local regCount = 0
	if regs.named then
		for k,r in pairs(regs.named) do
			if r.referred then 
				regCount = math.max( r.number, regCount )
			end
		end
	end
	self.regCount     = regCount
	self.builtStates  = builtStates
	self.emitterNodes = emitters
	self._built = true	
end

function EffectNodeParticleSystem:buildSystem( system )
	assert( self._built )
	local states = self.builtStates
	system = system or MOAIParticleSystem.new()
	system:reserveStates( #states )
	for i, s in ipairs( states ) do
		system:setState( i, s )
	end
	system:reserveSprites   ( self.spriteLimit )
	system:reserveParticles ( self.particleLimit, self.regCount )
	system:setReversedDrawOrder( true )

	system.config = self
	setupMoaiProp( system, self )
	--add emitters
	local emitters = {}
	local forces   = {}
	for _, node in pairs( self.emitterNodes ) do
		local em = node:buildEmitter()
		em:setSystem( system )
		em:start()
		emitters[ em ] = true
	end
	system:start()
	return system, emitters, forces
end

function EffectNodeParticleSystem:onLoad( emitter )
	local prop = emitter.prop
	local system, emitters, forces = self:buildSystem()	
	if self.syncTransform then --attach system only
		inheritPartition( system, prop )
		inheritTransform( system, prop )
	else --attach emitter/forces only
		inheritPartition( system, prop )
		for em in pairs( emitters ) do
			inheritTransform( em, prop )
		end
		for f in pairs( forces ) do
			inheritLoc( f, prop )
		end
	end
end
--------------------------------------------------------------------
--CLASS:  EffectNodeParticleState
--------------------------------------------------------------------
CLASS: ParticleScriptParam ()

function ParticleScriptParam:get()
end

function ParticleScriptParam:set( ... )
end

--------------------------------------------------------------------
CLASS: ParticleScriptParamNumber ( ParticleScriptParam )
	:MODEL{
 		Field 'key'    :string();
 		Field 'value'  :number();
	}

function ParticleScriptParamNumber:__init()
	self.value = 1
end

function ParticleScriptParamNumber:set( v )
	self.value = v
end

function ParticleScriptParamNumber:get()
	return self.value
end

--------------------------------------------------------------------
CLASS: ParticleScriptParamColor ( ParticleScriptParam )
	:MODEL{
 		Field 'key'    :string();
 		Field 'color'  :type('color');
	}
function ParticleScriptParamColor:__init()
	self.color = {1,1,1,1}
end

function ParticleScriptParamColor:set( r,g,b,a )
	self.color = {
		r or 1,
		g or 1,
		b or 1,
		a or 1,
	}
end

function ParticleScriptParamColor:get()
	return unpack( self.color )
end

--------------------------------------------------------------------
--------------------------------------------------------------------
EffectNodeParticleState :MODEL{
		Field 'name'         :string() ;
		Field 'active'       :boolean() ;
		Field 'life'         :type('vec2') :range(0) :getset('Life');
		Field 'script'       :string() :no_edit();
		Field 'params'       :array( ParticleScriptParam ) :sub() :no_edit();
	}

function EffectNodeParticleState:__init()
	self.name         = 'state'
	self.active       = true
	self.life         = { 1, 1 }
	self.script = [[
function render()
	proc.p.moveAlong()
	sprite()
end
]]
	self.params = {}
	self.moaiParticleState = MOAIParticleState.new()
end

function EffectNodeParticleState:getParamN( k )	
	local par = self.params[ k ]
	if not par then return 0 end
	return par:get()
end

function EffectNodeParticleState:setParamN( k, v )
	local par = self.params[ k ]
	if not par then
		par = ParticleScriptParamNumber()
		self.params[ k ] = par
	end
	par:set( v )
end

function EffectNodeParticleState:getParamC( k )	
	local par = self.params[ k ]
	if not par then return 1,1,1,1 end
	return par:get()
end

function EffectNodeParticleState:getParamCStr( k )	
	local r,g,b,a = self:getParamC( k )
	return string.format( '%.3f,%.3f,%.3f,%.3f', r,g,b,a )
end

function EffectNodeParticleState:setParamC( k, r,g,b,a )
	local par = self.params[ k ]
	if not par then
		par = ParticleScriptParamColor()
		self.params[ k ] = par
	end
	par:set( r,g,b,a )
end

function EffectNodeParticleState:_buildState( regs )
	regs = regs or {}
	local script = self.script

	--find params
	--find number params
	local params = self.params
	for n in string.gmatch( script, '${(%w+)}' ) do
		if not params[ n ] then			
			self:setParamN( n, 1 )
		end
	end

	--find color params
	for n in string.gmatch( script, '${{(%w+)}}' ) do
		if not params[ n ] then
			self:setParamC( n, 1,1,1,1 )
		end
	end
	
	local script1 = script:gsub(
		'${(%w+)}', 
		function(k) return self:getParamN( k ) end
	)
	script1 = script1:gsub(
		'${{(%w+)}}', 
		function(k) return self:getParamCStr( k ) end
	)
	
	local chunk = loadstring( script1 )
	local env = {}
	setfenv( chunk, env )
	pcall( chunk )
	local initFunc   = env['init']
	local renderFunc = env['render']

	local iscript = initFunc and makeParticleScript( initFunc, regs ) or false
	local rscript = renderFunc and makeParticleScript( renderFunc, regs ) or false
	builtScripts = { iscript, rscript }
	
	local state = self.moaiParticleState
	state:clearForces()

	if self.damping  then state:setDamping( self.damping ) end
	if self.mass     then state:setMass( _unpack(self.mass) ) end
	if self.life     then state:setTerm( _unpack(self.life) ) end

	if iscript then state:setInitScript   ( iscript ) end
	if rscript then state:setRenderScript ( rscript ) end
	return state
end

function EffectNodeParticleState:setLife( l1, l2 )
	self.life         = { l1, l2 or l1 }
end

function EffectNodeParticleState:getLife()
	return unpack( self.life )
end


----------------------------------------------------------------------
--CLASS: EffectNodeParticleEmitter
--------------------------------------------------------------------
EffectNodeParticleEmitter :MODEL {
		Field 'emission'  :type('vec2') :range(0)  :getset('Emission');		
		Field 'duration'  :number();
		Field 'surge'     :int();
		'----';
		Field 'magnitude' :type('vec2') :range(0)  :getset('Magnitude');		
		Field 'angle'     :type('vec2') :range(-360, 360) :getset('Angle');	
		'----';
		Field 'radius'    :type('vec2') :range(0) :getset('Radius');
		Field 'rect'      :type('vec2') :range(0) :getset('Rect');
	}

function EffectNodeParticleEmitter:__init()
	self.name      = 'emitter'
	self.magnitude = { 10, 10 }
	self.angle     = { 0, 0 }
	self.surge     = 0
	self.emission  = {1,1}
	self.radius    = {5,5}
	self.rect      = {0,0}
	self.duration  = -1
end

function EffectNodeParticleEmitter:updateEmitterCommon( em )
	em.name = self.name
	if self.angle     then em:setAngle( _unpack(self.angle) ) end
	if self.magnitude then em:setMagnitude( _unpack(self.magnitude) ) end
	if self.radius[1] > 0 or self.radius[1] > 0 then 
		em:setRadius( _unpack(self.radius) )
	else
		local w, h = unpack( self.rect )
		em:setRect( -w/2, -h/2, w/2, h/2 )
	end
	if self.emission then em:setEmission(_unpack(self.emission)) end
	if self.surge    then em:surge(self.surge) end
	if em.setDuration then 
		em:setDuration( self.duration )
	end
end

function EffectNodeParticleEmitter:getDefaultName()
	return 'emitter'
end

function EffectNodeParticleEmitter:buildEmitter()
	local emitter = MOAIParticleTimedEmitter.new()
	emitter:updateEmitterCommon( emitter )
	return emitter
end

--------------------------------------------------------------------
function EffectNodeParticleEmitter:setEmission( e1, e2 )
	self.emission = { e1 or 0 , e2 or 0 }
end

function EffectNodeParticleEmitter:getEmission()
	return unpack( self.emission )
end

function EffectNodeParticleEmitter:setMagnitude( min, max )
	min = min or 0
	self.magnitude = { min, max or min }
end

function EffectNodeParticleEmitter:getMagnitude()
	return unpack( self.magnitude )
end

function EffectNodeParticleEmitter:setAngle( min, max )
	min = min or 0
	self.angle = { min, max or min }
end

function EffectNodeParticleEmitter:getAngle()
	return unpack( self.angle )
end

function EffectNodeParticleEmitter:setRadius( r1, r2 )
	self.radius = { r1 or 0 , r2 or 0 }
end

function EffectNodeParticleEmitter:getRadius()
	return unpack( self.radius )
end

function EffectNodeParticleEmitter:setRect( w, h )
	self.rect = { w or 1, h or 1 }
end

function EffectNodeParticleEmitter:getRect()
	return unpack( self.rect )
end


--------------------------------------------------------------------
--CLASS: EffectNodeParticleTimedEmitter
--------------------------------------------------------------------
CLASS: EffectNodeParticleTimedEmitter( EffectNodeParticleEmitter )
:MODEL{
	Field 'frequency' :type('vec2') :range(0)  :getset('Frequency');
}

function EffectNodeParticleTimedEmitter:__init()
	self.frequency = { 10, 10 }
end

function EffectNodeParticleTimedEmitter:buildEmitter()
	local emitter = MOAIParticleTimedEmitter.new()
	self:updateEmitterCommon( emitter )
	local f1, f2 = _unpack( self.frequency )		
	emitter:setFrequency( 1/f1, f2 and 1/f2 or 1/f1 )
	return emitter
end

function EffectNodeParticleEmitter:setFrequency( f1, f2 )
	self.frequency = { f1 or 0 , f2 or 0 }
end

function EffectNodeParticleEmitter:getFrequency()
	return unpack( self.frequency )
end

--------------------------------------------------------------------
--CLASS: EffectNodeParticleDistanceEmitter
--------------------------------------------------------------------
CLASS: EffectNodeParticleDistanceEmitter( EffectNodeParticleEmitter )
:MODEL{
	Field 'distance'  :number()  :range(0) ;
}

function EffectNodeParticleDistanceEmitter:__init()
	self.distance  = 10
end

function EffectNodeParticleDistanceEmitter:buildEmitter()
	local emitter = MOAIParticleDistanceEmitter.new()
	self:updateEmitterCommon( emitter)
	emitter:setDistance( _unpack( self.distance ) )
	return emitter
end

----------------------------------------------------------------------
--CLASS: EffectNodeParticleForce
--------------------------------------------------------------------
EffectNodeParticleForce :MODEL{
	Field 'loc'       :type('vec3') :getset('Loc') :label('Loc'); 
	Field 'forceType' :enum( EnumParticleForceType ) :set( 'setForceType' );
}

function EffectNodeParticleForce:__init()
	self.moaiParticleForce = MOAIParticleForce.new()
end

function EffectNodeParticleForce:getDefaultName()
	return 'force'
end

function EffectNodeParticleForce:setForceType( t )
	self.moaiParticleForce:setType( t )
end

function EffectNodeParticleForce:setLoc( x,y,z )
	self.moaiParticleForce:setLoc( x,y,z )
end

function EffectNodeParticleForce:getLoc()
	return self.moaiParticleForce:getLoc()
end

--------------------------------------------------------------------
CLASS: EffectNodeForceAttractor ( EffectNodeParticleForce )
	:MODEL{
		Field 'radius';
		Field 'magnitude';
}

function EffectNodeForceAttractor:__init()
	self.radius = 100
	self.magnitude = 1	
end

function EffectNodeForceAttractor:onBuild()
	self.moaiParticleForce:initAttractor( self.radius, self.magnitude )
end

--------------------------------------------------------------------
CLASS: EffectNodeBasinForce ( EffectNodeParticleForce )
	:MODEL{
		Field 'radius';
		Field 'magnitude';
}

function EffectNodeBasinForce:__init()
	self.radius = 100
	self.magnitude = 1	
end

function EffectNodeBasinForce:onBuild()
	self.moaiParticleForce:initBasin( self.radius, self.magnitude )
end

--------------------------------------------------------------------
CLASS: EffectNodeForceLinear ( EffectNodeParticleForce )
	:MODEL{
		Field 'vector'       :type('vec3') :getset('Vector') :label('Loc'); 
}

function EffectNodeForceLinear:__init()
	self.vector = {1,0,0}
end

function EffectNodeForceLinear:setVector( x,y,z )
	self.vector = {x,y,z}
	self:update()	
end

function EffectNodeForceLinear:getVector()
	return unpack( self.vector )
end

function EffectNodeForceLinear:onBuild()
	self.moaiParticleForce:initLinear( unpack( self.vector ) )
end


--------------------------------------------------------------------
CLASS: EffectNodeForceRadial ( EffectNodeParticleForce )
	:MODEL{
		Field 'magnitude';
}

function EffectNodeForceRadial:__init()
	self.magnitude = 1	
end

function EffectNodeForceRadial:onBuild()
	self.moaiParticleForce:initRadial( self.radius, self.magnitude )
end

