module 'mock'
--------------------------------------------------------------------
CLASS: ParticleSystem ()
	:MODEL {
		Field 'config'  :asset( 'particle_.+' ) :getset( 'Config' );

	}

function ParticleSystem:__init( config )
	self._system = false
	-- self:setConfig( config )	
	self.emitters = {}
end

function ParticleSystem:onAttach( entity )
	if self._system then 
		entity:_attachProp( self._system )
	end
end

function ParticleSystem:onStart()
	self:start()
end

function ParticleSystem:onDetach( entity )
	self:stop()
	for em in pairs( self.emitters ) do
		em:stop()
	end
end

function ParticleSystem:getConfig()
	return self.configPath
end

function ParticleSystem:setConfig( configPath )
	self.configPath = configPath

	local config = mock.loadAsset( configPath )
	if self.config then
		self:stop()
	end	
	self.config = config
	if config then
		self._system = config:requestSystem()
		if self._entity then
			self._entity:_attachProp( self._system )
		end
	end
	
end

--------------------------------------------------------------------
function ParticleSystem:start()
	if self._system then
		return self._system:start()
	end
end

function ParticleSystem:stop()
	local sys = self._system
	if sys then
		sys:stop()
		self._entity:_detachProp( sys )
		self.config:_pushToPool( sys )
		self._system = false
	end
end

--------------------------------------------------------------------
function ParticleSystem:addEmitter( emitterName )
	local config = self.config
	if not config then
		_error('particle has no config loaded')
		return nil
	end
	--check dead emitter
	local toRemove = {}
	local emitters = self.emitters
	for em in pairs( emitters ) do
		if em:isDone() then
			toRemove[ em ] = true
		end
	end
	for em in pairs(toRemove) do
		emitters[ em ] = nil			
	end

	if not emitterName then
		local em = MOAIParticleTimedEmitter.new()
		self._entity:_attachTransform( em )
		em:forceUpdate()
		em:setSystem( self._system )		
		em:start()
		self.emitters[ em ] = true
		return em
	end

	local em = config:buildEmitter( emitterName )
	self._entity:_attachTransform( em )
	em:forceUpdate()
	em:setSystem( self._system )
	em:start()
	self.emitters[ em ] = true
	--TODO: attach as new component?
	return em
end

function ParticleSystem:clearEmitters()
	for em in pairs( self.emitters ) do
		em:stop()
	end
	self.emitters = {}
end

function ParticleSystem:addForceToAll( force )
end

function ParticleSystem:addForceToState( stateName, force )
end

--------------------------------------------------------------------
mock.registerComponent( 'ParticleSystem', ParticleSystem )

