module 'mock'

local ccreate, cresume, cyield, cstatus
	= coroutine.create, coroutine.resume, coroutine.yield, coroutine.status

local insert, remove = table.insert, table.remove
--------------------------------------------------------------------

CLASS: SQNode ()
CLASS: SQRoutine ()
CLASS: SQScript ()

CLASS: SQState ()



--------------------------------------------------------------------
SQNode :MODEL{
		Field 'index'   :int() :no_edit(); 
		Field 'comment' :string() :no_edit(); 
		Field 'active'  :boolean() :no_edit(); 

		Field 'parentRoutine' :type( SQRoutine ) :no_edit();
		Field 'parentNode' :type( SQNode ) :no_edit();
		Field 'children'   :array( SQNode ) :no_edit();
}

function SQNode:__init()
	self.parentRoutine = false
	
	self.index      = 0
	self.depth      = 0
	self.active     = true
	self.parentNode = false
	self.children   = {}

	self.comment    = ''

	self.context    = false
	self.tags       = false

end

function SQNode:getFirstContext()
	if self.context then
		return self.context[ 1 ]
	else
		return nil
	end
end

function SQNode:hasTag( t )
	if not self.tags then return false end
	for i, tag in ipairs( self.tags ) do
		if tag == t then return true end
	end
	return false
end

function SQNode:getRoot()
	return self.parentRoutine:getRootNode()
end

function SQNode:getChildren()
	return self.children
end

function SQNode:getFirstChild()
	return self.children[1]
end

function SQNode:getParent()
	return self.parentNode
end

function SQNode:getPrevSibling()
	local p = self.parentNode
	local siblings = p and p.children
	local index = table.index( siblings, self )
	return siblings[ index - 1 ]
end

function SQNode:getNextSibling()
	local p = self.parentNode
	local siblings = p and p.children
	local index = table.index( siblings, self )
	return siblings[ index + 1 ]
end

function SQNode:getRoutine()
	return self.parentRoutine
end

function SQNode:getScript()
	return self.parentRoutine:getScript()
end

function SQNode:isGroup()
	return false
end

function SQNode:canInsert()
	return false
end

function SQNode:isBuiltin()
	return false
end

function SQNode:isExecutable()
	return true
end

function SQNode:initFromEditor()
end

function SQNode:addChild( node, idx )
	node.parentNode = self
	node.parentRoutine = assert( self.parentRoutine )
	node.depth = self.depth + 1
	if idx then
		insert( self.children, idx, node )
	else
		insert( self.children, node )
	end
	return node
end

function SQNode:indexOfChild( node )
	return table.index( self.children, node )
end

function SQNode:removeChild( node )
	local idx = table.index( self.children, node )
	if not idx then return false end
	remove( self.children, idx )
	node.parentNode = false
	node.parentRoutine = false	
	return true
end

function SQNode:getName()
	return 'node'
end

function SQNode:getComment()
	return self.comment
end

function SQNode:getRichText()
	return 'SQNode'
end

function SQNode:getIcon()
	return false
end

function SQNode:setComment( c )
	self.comment = c
end

function SQNode:enter( state, env )
	return true
end

function SQNode:step( state, env, dt )
	return true
end

function SQNode:exit( state, env )
	return true
end

function SQNode:getContextEntity( state )
	local actor = state:getActor()
	return actor:getContextEntity( self.context[1] )
end

function SQNode:getContextEntities( state )
	local actor = state:getActor()
	return actor:getContextEntities( self.context )
end

function SQNode:_load( data )
	self.srcData = data
	self:load( data )
end

function SQNode:load( data )
end

function SQNode:applyNodeContext( buildContext )
	self.context = buildContext.context
	self.tags = buildContext.tags
	buildContext.tags = {}
end

function SQNode:_build( buildContext )
	self:applyNodeContext( buildContext )
	self:build( buildContext )
	self:buildChildren( buildContext )
	self.executeQueue = self:buildExecuteQueue() or {}
	-- self.executeQueue = self.children
end

function SQNode:build( buildContext )
end

function SQNode:buildChildren( buildContext )
	local context0 = buildContext.context
	for i, child in ipairs( self.children ) do
		child:_build( buildContext )
	end
	buildContext.context = context0
end

function SQNode:buildExecuteQueue()
	local queue = {}
	local index = 0
	for i, child in ipairs( self.children ) do
		if child:isExecutable() then
			index = index + 1
			child.index = index
			queue[ index ] = child
		end
	end
	return queue
end

function SQNode:acceptSubNode( name )
	return true
end

--------------------------------------------------------------------
CLASS: SQNodeGroup ( SQNode )
	:MODEL{
		Field 'name' :string();
}

function SQNodeGroup:__init()
	self.name = 'group'
end

function SQNodeGroup:isGroup()
	return true
end

function SQNodeGroup:canInsert()
	return true
end


function SQNodeGroup:getRichText()
	return string.format(
		'[ <group>%s</group> ]',
		self.name
		)
end

function SQNodeGroup:getIcon()
	return 'sq_node_group'
end


--------------------------------------------------------------------
CLASS: SQNodeLabel( SQNode )
	:MODEL{
		Field 'id' :string();
}

function SQNodeLabel:__init()
	self.id = 'label'
end

function SQNodeLabel:getRichText()
	return string.format(
		'<label>%s</label>',
		self.id
		)
end

function SQNodeLabel:getIcon()
	return 'sq_node_label'
end

function SQNodeLabel:build()
	local routine = self:getRoutine()
	routine:addLabel( self )
end


--------------------------------------------------------------------
CLASS: SQNodeGoto( SQNode )
	:MODEL {
		Field 'label' :string();
}

function SQNodeGoto:__init()
	self.label = 'label'
end

function SQNodeGoto:load( data )
	self.label = data.args[1]
end

function SQNodeGoto:enter( state, env )
	local routine = self:getRoutine()
	local targetNode = routine:findLabelNode( self.label )
	if not targetNode then
		_warn( 'target label not found', self.label )
		state:setJumpTarget( false )
	else
		state:setJumpTarget( targetNode )
	end
	return 'jump'
end

function SQNodeGoto:getRichText()
	return string.format(
		'<cmd>GOTO</cmd> <label>%s</label>',
		self.label
		)
end

function SQNodeGoto:getIcon()
	return 'sq_node_goto'
end



---------------------------------------------------------------------
CLASS: SQNodeEnd( SQNode )
	:MODEL{
		Field 'stopAllRoutines' :boolean()
}

function SQNodeEnd:__init()
	self.stopAllRoutines = false
end

function SQNodeEnd:enter( state )
	if self.stopAllRoutines then
		state:stop()
		return 'jump'
	else
		state._jumpTargetNode = false --jump to end
		return 'jump'
	end
end

function SQNodeEnd:getRichText()
	return string.format(
		'<end>END</end> <flag>%s</flag>',
		self.stopAllRoutines and 'All Routines' or ''
		)
end

function SQNodeEnd:getIcon()
	return 'sq_node_end'
end


--------------------------------------------------------------------
CLASS: SQNodeRoot( SQNodeGroup )



--------------------------------------------------------------------
CLASS: SQNodeSkip( SQNode )
function SQNodeSkip:isExecutable()
	return false
end


--------------------------------------------------------------------
CLASS: SQNodeContext ( SQNode )
function SQNodeContext:__init()
	self.contextNames = {}
end

function SQNodeContext:applyNodeContext( buildContext )
	buildContext.context = self.contextNames
end

function SQNodeContext:isExecutable()
	return false
end

function SQNodeContext:load( data )
	self.contextNames = data.names
end


--------------------------------------------------------------------
CLASS: SQNodeTag ( SQNode )
function SQNodeTag:__init()
	self.tagNames = {}
end

function SQNodeTag:applyNodeContext( buildContext )
	buildContext.tags = table.merge( buildContext.tags or {}, self.tagNames )
end

function SQNodeTag:isExecutable()
	return false
end

function SQNodeTag:load( data )
	self.tagNames = data.tags or {}
end


--------------------------------------------------------------------
SQRoutine :MODEL{
		Field 'name' :string();
		Field 'autoStart' :boolean();
		Field 'comment' :string();
		Field 'rootNode' :type( SQNode ) :no_edit();
		Field 'parentScript' :type( SQScript ) :no_edit();
}

function SQRoutine:__init()
	self.parentScript   = false

	self.rootNode = SQNodeRoot()	
	self.rootNode.parentRoutine = self
	self.autoStart = false

	self.name = 'unnamed'
	self.comment = ''

	self.labelNodes = {}
	self.msgCallbackNodes = {}
end

function SQRoutine:getScript()
	return self.parentScript
end

function SQRoutine:findLabelNode( id )
	for i, node in ipairs( self.labelNodes ) do
		if node.id == id then return node end
	end
	return nil
end

function SQRoutine:addLabel( labelNode )
	insert( self.labelNodes, labelNode )
end


function SQRoutine:addMsgCallback( msg, node )
	table.insert( self.msgCallbackNodes, node )
	return node
end

function SQRoutine:getName()
	return self.name
end

function SQRoutine:setName( name )
	self.name = name
end

function SQRoutine:getComment()
	return self.comment
end

function SQRoutine:setComment( c )
	self.comment = c
end

function SQRoutine:getRootNode()
	return self.rootNode
end

function SQRoutine:addNode( node, idx )
	return self.rootNode:addChild( node, idx )
end

function SQRoutine:removeNode( node )
	return self.rootNode:removeChild( node )
end

function SQRoutine:execute( state )
	return state:executeRoutine( self )
end

function SQRoutine:build()
	local context = {
		context = {},
		tags    = {}
	}
	self.rootNode:_build( context )
end


--------------------------------------------------------------------
SQScript :MODEL{
		Field 'comment';	
		Field 'routines' :array( SQRoutine ) :no_edit();
}

function SQScript:__init()
	self.routines = {}
	self.comment = ''
	self.built = false
end

function SQScript:addRoutine( routine )
	local routine = routine or SQRoutine()
	routine.parentScript = self
	insert( self.routines, routine )
	return routine
end

function SQScript:removeRoutine( routine )
	local idx = table.index( self.routines, routine )
	if not idx then return end
	routine.parentRoutine = false
	remove( self.routines, idx )
end

function SQScript:getRoutines()
	return self.routines
end

function SQScript:getComment()
	return self.comment
end

function SQScript:_postLoad( data )
end

function SQScript:build()
	if self.built then return true end
	self.built = true
	for i, routine in ipairs( self.routines ) do
		routine:build()
	end
	return true
end


--------------------------------------------------------------------
CLASS: SQRoutineState ()
 
function SQRoutineState:__init( entryNode, routine )
	self.routine = entryNode:getRoutine()
	self.globalState = false

	self.localRunning = false
	self.started = false
	self.jumpTarget = false

	self.entryNode = entryNode

	self.currentNode = false
	self.currentNodeEnv = false
	self.currentQueue = {}
	self.index = 1
	self.nodeEnvMap = {}

	self.msgListeners = {}

	self.subRoutineStates = {}
	return self:reset()
end

function SQRoutineState:getActor()
	return self.globalState:getActor()
end

function SQRoutineState:setLocalRunning( localRunning )
	self.localRunning = localRunning
	if self.parentState then
		return self.parentState:updateChildrenRunningState()
	end
end

function SQRoutineState:updateChildrenRunningState()
	local childrenRunning = nil
	local newStates = {}
	for i, sub in ipairs( self.subRoutineStates ) do
		if sub.localRunning then
			insert( newStates, sub )
			childrenRunning = childrenRunning == nil
		else
			childrenRunning = false
		end
	end
	self.subRoutineStates = newStates
	self.childrenRunning = childrenRunning or false
end

function SQRoutineState:start( sub )
	if self.started then return end
	self.started = true
	self:setLocalRunning( true )
	if not sub then
		self:registerMsgCallbacks()
	end
end

function SQRoutineState:stop()
	for i, subState in ipairs( self.subRoutineStates ) do
		subState:stop()
	end
	self.subRoutineStates = {}
end

function SQRoutineState:isRunning()
	if self.localRunning then return true end
	for i, substate in ipairs( self.subRoutineStates ) do
		if subState:isRunning() then return true end
	end
	return false
end

function SQRoutineState:reset()
	self.started = false
	
	self.localRunning = false
	self.jumpTarget = false

	self.subRoutineStates = {}
	self.nodeEnvMap = {}
	self.currentNodeEnv = false

	local env = {}
	local entry = self.entryNode
	self.currentNode = entry
	self.currentQueue = {}
	self.currentNodeEnv = env
	self.nodeEnvMap[ entry ] = env

end

function SQRoutineState:restart()
	self:reset()
	self:start()
end

function SQRoutineState:getNodeEnvTable( node )
	return self.nodeEnvMap[ node ]
end

function SQRoutineState:registerMsgCallbacks()
	local msgListeners = table.weak_k()
	-- for i, entryNode in ipairs( )
	for i, callbackNode in ipairs( self.routine.msgCallbackNodes ) do
		for j, target in ipairs( callbackNode:getContextEntities( self ) ) do
			local msg1 = callbackNode.msg
			local listener = function( msg, data, src )
				if msg == msg1 then
					return self:startSubRoutine( callbackNode )
				end
			end
			target:addMsgListener( listener )
			msgListeners[ target ] = listener
		end
	end
	self.msgListeners = msgListeners
end

function SQRoutineState:unregisterMsgCallbacks()
	if not self.msgListeners then return end
	for target, listener in pairs( self.msgListeners ) do
		target:removeMsgListener( listener )
	end
end

function SQRoutineState:startMsgCallback( msg )
	local queue = self.routine:findMsgCallback( msg )
	if queue then
		for i, entryNode in ipairs( queue ) do
			self:startSubRoutine( entryNode )
		end
	end
end

function SQRoutineState:startSubRoutine( entryNode )
	local subState = SQRoutineState( entryNode )
	subState.globalState = self.globalState
	subState.parentState = self
	insert( self.subRoutineStates, subState )
	subState:start( 'sub' )
end

function SQRoutineState:getSignalCounter( id )
	return self.globalState:getSignalCounter( id )
end

function SQRoutineState:incSignalCounter( id )
	return self.globalState:incSignalCounter( id )
end

function SQRoutineState:getEnv( key, default )
	return self.globalState:getEnv( key, default )
end

function SQRoutineState:setEnv( key, value )
	return self.globalState:setEnv( key, value )
end

function SQRoutineState:getEvalEnv()
	return self.globalState.varTable
end

function SQRoutineState:update( dt )
	for i, subState in ipairs( self.subRoutineStates ) do
		subState:update( dt )
	end
	if self.localRunning then
		self:updateNode( dt )
	end
end

function SQRoutineState:updateNode( dt )
	local node = self.currentNode
	if node then
		local env = self.currentNodeEnv
		local res = node:step( self, env, dt )
		if res then
			if res == 'jump' then
				return self:doJump()
			end
			return self:exitNode()
		end
	else
		return self:nextNode()
	end
end

function SQRoutineState:nextNode()
	local index1 = self.index + 1
	local node1 = self.currentQueue[ index1 ]
	if not node1 then
		return self:exitGroup()
	end
	self.index = index1
	self.currentNode = node1
	local env = {}
	self.currentNodeEnv = env
	self.nodeEnvMap[ node1 ] = env
	local res = node1:enter( self, env )
	if res == 'jump' then
		return self:doJump()
	end
	if res == false then
		return self:nextNode()
	end
	return self:updateNode( 0 )
end

function SQRoutineState:exitNode( fromGroup )
	local node = self.currentNode
	if node:isGroup() then --Enter group
		self.index = 0
		self.currentQueue = node.executeQueue
	else
		local res = node:exit( self, self.currentNodeEnv )
		if res == 'jump' then
			return self:doJump()
		end
	end
	return self:nextNode()
end

function SQRoutineState:exitGroup()
	--exit group node
	local groupNode = self.currentNode.parentNode
	if not groupNode then
		self:setLocalRunning( false )
		return true
	end

	local env = self.nodeEnvMap[ groupNode ] or {}
	local res = groupNode:exit( self, env )

	if res == 'jump' then
		return self:doJump()
	elseif res == 'loop' then
		--Loop
		self.index = 0
	elseif res == 'end' then
		self:setLocalRunning( false )
		return true
	else
		local parentNode = groupNode.parentNode
		if (not parentNode) then
			self:setLocalRunning( false )
			return true
		end
		self.currentNode  = groupNode
		self.currentQueue = parentNode.executeQueue
		self.index = groupNode.index
	end
	return self:nextNode()
end

function SQRoutineState:setJumpTarget( node )
	self.jumpTarget = node
end

function SQRoutineState:doJump()
	local target = self.jumpTarget
	if not target then
		self.localRunning = false
		return false
	end

	self.jumpTarget = false
	self.currentNode  = false
	local parentNode = target.parentNode
	self.currentQueue = parentNode.executeQueue
	self.index = target.index - 1
	
	return self:nextNode()
	
end

--------------------------------------------------------------------
SQState :MODEL{
	
}

function SQState:__init()
	self.script  = false
	self.paused  = false

	self.routineStates = {}
	self.coroutines = {}
	self.signalCounters = {}
	self.env = {}
	self.varTable = {}
end

function SQState:getEnv( key, default )
	local v = self.env[ key ]
	if v == nil then return default end
	return v
end

function SQState:setEnv( key, value )
	self.env[ key ] = value
end

function SQState:getActor()
	return self.env['actor']
end

function SQState:getSignalCounter( id )
	return self.signalCounters[ id ] or 0
end

function SQState:incSignalCounter( id )
	local v = ( self.signalCounters[ id ] or 0 ) + 1
	self.signalCounters[ id ] = v
	return v
end


function SQState:isPaused()
	return self.paused
end

function SQState:pause( paused )
	self.paused = paused ~= false
end

function SQState:isRunning()
	for i, routineState in ipairs( self.routineStates ) do
		if routineState:isRunning() then return true end
	end
	return false
end

function SQState:stop()
	for i, routineState in ipairs( self.routineStates ) do
		routineState:stop()
	end
end

function SQState:loadScript( script )
	script:build()
	self.script = script
	for i, routine in ipairs( script.routines ) do
		local entryNode    = routine:getRootNode()
		local routineState = SQRoutineState( entryNode )
		routineState.routine = routine
		routineState.globalState = self
		routineState.parentState = false
		insert( self.routineStates, routineState )
		if routine.autoStart then
			routineState:start()
		end
	end
end

function SQState:update( dt )
	if self.paused then return end
	for i, routineState in ipairs( self.routineStates ) do
		routineState:update( dt )
	end
end

function SQState:findRoutineState( name )
	for i, routineState in ipairs( self.routineStates ) do
		if routineState.routine.name == name then return routineState end
	end
	return nil
end

function SQState:stopRoutine( name )
	local rc = self:findRoutineState( name )
	if rc then
		rc:stop()
		return true
	end
end

function SQState:startRoutine( name )
	local rc = self:findRoutineState( name )
	if rc then
		rc:start()
		return true
	end
end

function SQState:restartRoutine( name )
	local rc = self:findRoutineState( name )
	if rc then
		rc:restart()
		return true
	end
end

function SQState:isRoutineRunning( name )
	local rc = self:findRoutineState( name )
	if rc then 
		return rc:isRunning()
	end
	return nil
end

function SQState:startAllRoutines()
	for i, routineState in ipairs( self.routineStates ) do
		if not routineState.started then
			routineState:start()
		end
	end
	return true
end

--------------------------------------------------------------------
local SQNodeRegistry = {}
local defaultOptions = {}
function registerSQNode( name, clas, overwrite, info )
	assert( clas, 'nil class?' .. name )
	info = info or {}
	local entry0 = SQNodeRegistry[ name ]
	if entry0 then
		if not overwrite then
			_warn( 'duplicated SQNode:', name )
			return false
		end
	end
	SQNodeRegistry[ name ] = {
		clas     = clas,
		info     = info
	}
end

function findInSQNodeRegistry( name )
	return SQNodeRegistry[ name ]
end

function getSQNodeRegistry()
	return SQNodeRegistry
end



--------------------------------------------------------------------
local function loadSQNode( data, parentNode )
	local node
	local t = data.type
	if t == 'context' then
		node = SQNodeContext()
		node:_load( data )
		parentNode:addChild( node )

	elseif t == 'tag'     then
		node = SQNodeTag()
		node:_load( data )
		parentNode:addChild( node )

	elseif t == 'label'   then
		local labelNode = SQNodeLabel()
		labelNode.id = data.id
		parentNode:addChild( labelNode )
		return labelNode

	elseif t == 'action' then
		--find action node factory
		local actionName = data.name
		local entry = SQNodeRegistry[ actionName ]
		if not entry then
			_error( 'unkown action node type', actionName )
			return SQNode() --dummy node
		end
		local clas = entry.clas
		node = clas()
		node:_load( data )
		parentNode:addChild( node )

	elseif t == 'root' then
		--pass
		node = parentNode

	else
		--error
		error( 'wtf?', t )
	end

	for i, childData in ipairs( data.children ) do
		loadSQNode( childData, node )
	end

	return node

end

--------------------------------------------------------------------
function loadSQScript( node )
	local data   = mock.loadAssetDataTable( node:getObjectFile('data') )
	local script = SQScript()
	local routine = script:addRoutine()
	routine.name = 'main'
	routine.autoStart = true
	loadSQNode( data, routine.rootNode )
	script:build()
	return script
end

--------------------------------------------------------------------
registerSQNode( 'group', SQNodeGroup )
registerSQNode( 'do',    SQNodeGroup )
registerSQNode( 'end',   SQNodeEnd   )
registerSQNode( 'goto',  SQNodeGoto  )
registerSQNode( 'skip',  SQNodeSkip  )

mock.registerAssetLoader( 'sq_script', loadSQScript )
