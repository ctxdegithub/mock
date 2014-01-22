module 'mock'

local EVENT_SPINE_ANIMATION_START    = MOAISpineAnimationState.EVENT_SPINE_ANIMATION_START
local EVENT_SPINE_ANIMATION_END      = MOAISpineAnimationState.EVENT_SPINE_ANIMATION_END
local EVENT_SPINE_ANIMATION_COMPLETE = MOAISpineAnimationState.EVENT_SPINE_ANIMATION_COMPLETE
local EVENT_SPINE_ANIMATION_EVENT    = MOAISpineAnimationState.EVENT_SPINE_ANIMATION_EVENT

CLASS: SpineSprite ( SpineSpriteBase )
	:MODEL{
		Field 'defaultClip' :string()  :label('Default') :selection( 'getAnimationNames' );
		Field 'autoPlay'    :boolean() :label('Auto Play');
	}

registerComponent( 'SpineSprite', SpineSprite )

function SpineSprite:__init()
	self.animState     = false
	self.skeletonData  = false
	self.defaultClip   = ''
	self.autoPlay      = true
	self._onAnimationEvent  = false
	self.throttle      = 1
	self.mixTable      = false
end

function SpineSprite:onStart( entity )
	local default = self.defaultClip
	if self.autoPlay and default and default ~= '' then
		self:play( default, MOAITimer.LOOP )
	end
end

local function _onSpineAnimationEvent( anim, trackId, name, varInt, varFloat, varString )
	return anim.owner:onAnimationEvent( trackId, name, varInt, varFloat, varString )
end

local function _onSpineAnimationComplete( anim, trackId, loopCount )
	return anim.owner:onAnimationComplete( trackId, loopCount )
end

function SpineSprite:getSkeleton()
	return self.skeleton
end

function SpineSprite:getSkeletonData()
	return self.skeletonData
end

function SpineSprite:play( clipName, mode, resetPose )
	if self.animState then
		self.animState:stop( resetPose )
	end
	mode = mode or MOAITimer.NORMAL
	local anim = self:createState()
	anim:setMode( mode )
	if not self:affirmClip( clipName ) then
		_traceback()
		_warn( 'spine anim clip not found:', clipName )
		return false
	end
	
	if resetPose ~= false then
		self.skeleton:setToSetupPose()
	end

	local track = anim:addTrack()
	local span = track:addSpan( 
		0, 
		clipName, 
		mode == MOAITimer.LOOP,
		0,
		10000
	)
	anim:setSpan( 10000 )
	anim:start()
	anim.owner = self
	-- anim:setListener( EVENT_SPINE_ANIMATION_EVENT, _onSpineAnimationEvent )
	-- anim:setListener( EVENT_SPINE_ANIMATION_COMPLETE, _onSpineAnimationComplete )
	self.animState = anim 
	return anim
end


function SpineSprite:createState()
	local anim = MOAISpineAnimation.new()
	anim:init( self.skeletonData )
	anim:setSkeleton( self.skeleton )
	if self.mixTable then anim:setMixTable( self.mixTable ) end
	anim:throttle( self.throttle )
	return anim
end

function SpineSprite:setThrottle( th )
	self.throttle = th
	if self.animState then
		self.animState:throttle( th )
	end
end

function SpineSprite:stop( resetPose )
	if self.animState then
		self.animState:stop()
	end
	if resetPose ~= false then
		self.skeleton:setToSetupPose()
	end
end

function SpineSprite:pause( paused )
	if self.animState then
		self.animState:pause( paused )
	end
end

function SpineSprite:resume()
	return self:pause( false )
end

function SpineSprite:setAnimationEventListener( listener )
	self._onAnimationEvent = listener
end

function SpineSprite:onAnimationEvent( trackId, evName, varInt, varFloat, varString )
	local callback = self._onAnimationEvent
	if callback then
		return callback( evName, varInt, varFloat, varString )
	end
end

function SpineSprite:getAnimationNames()
	return nil
end