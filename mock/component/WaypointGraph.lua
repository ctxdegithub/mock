module 'mock'

---------------------------------------------------------------------
CLASS: Waypoint ()
	:MODEL{}

function Waypoint:__init()
	self.parentGraph = false
	self.name  = 'waypoint'
	self.trans = MOAITransform.new()
	self.nodeId = false
	self.neighbours = {}
end

function Waypoint:getTransform()
	return self.trans
end

function Waypoint:isNeighbour( p1 )
	return self.neighbours[ p1 ] and true or false
end

function Waypoint:addNeighbour( p1 )
	if not self.nodeId then return false end
	if p1 == self then return false end
	p1.neighbours[ self ] = true
	self.neighbours[ p1 ] = true
	self.parentGraph.needRebuild = true
	return true
end

function Waypoint:removeNeighbour( p1 )
	if not self.nodeId then return false end
	if p1 == self then return false end
	p1.neighbours[ self ] = nil
	self.neighbours[ p1 ] = nil
	self.parentGraph.needRebuild = true
	return true
end

function Waypoint:getLoc()
	return self.trans:getLoc()
end

function Waypoint:getWorldLoc()
	self.trans:forceUpdate()
	return self.trans:getWorldLoc()
end

function Waypoint:setLoc( x, y, z )
	self.trans:setLoc( x, y, z )
	self.parentGraph.needRebuild = true
end

--------------------------------------------------------------------
CLASS: WaypointGraph ( Component )
	:MODEL{
		Field 'maxTotalIteration'  :int() :range( 1 );
		Field 'maxSingleIteration' :int() :range( 1 );
}

registerComponent( 'WaypointGraph', WaypointGraph )

function WaypointGraph:__init()
	self.waypoints = {}
	self.nodeCount = 0
	self.pathGraph = MOAIVecPathGraph.new()
	self.finderQueue = {}
	self.maxTotalIteration  = 50
	self.maxSingleIteration = 5
	self.trans = MOAITransform.new()
	self.needRebuild = true
end

function WaypointGraph:onAttach( ent )
	ent:_attachTransform( self.trans )
end

function WaypointGraph:onDetach( ent )
end

function WaypointGraph:addPathFinder( pf, prior )
	if prior then
		table.insert( self.finderQueue, 1, pf )
	else
		table.insert( self.finderQueue, pf )
	end
end

function WaypointGraph:updatePathFinders()
	local totalIteration = 0
	local maxTotalIteration  = self.maxTotalIteration
	local maxSingleIteration = self.maxSingleIteration

	for i, pf in ipairs( self.finderQueue ) do
		local singleIteration
		if totalIteration < maxTotalIteration then
			singleIteration = SINGLE_ITERATION
			totalIteration  = totalIteration + singleIteration
		else
			return 
		end

		if not pf:findPath( singleIteration ) then
			self:reportPath( pf )
		end

	end
end

function WaypointGraph:addWaypoint()
	local p = Waypoint()
	self.nodeCount = self.nodeCount + 1
	p.nodeId = self.nodeCount	
	p.parentGraph = self
	inheritTransform( p.trans, self.trans )
	table.insert( self.waypoints, p )
	self.needRebuild = true
	return p
end

function WaypointGraph:removeWaypoint( wp )
	local idx = table.index( self.waypoints, wp )
	if not idx then return false end
	table.remove( self.waypoints, idx )
	self.nodeCount = self.nodeCount - 1
	local waypoints = self.waypoints
	for i = idx, self.nodeCount do
		local p = waypoints[ i ]
		p.nodeId = i
	end
	self.needRebuild = true
end

function WaypointGraph:getWaypoint( id )
	return self.waypoints[ id ]
end


function WaypointGraph:findWaypointByName( name )
	for i, p in ipairs( self.waypoints ) do
		if p.name == name then return p end
	end
	return nil
end

function WaypointGraph:connectWaypoints( id1, id2 )
	local p1 = self.waypoints[ id1 ]
	local p2 = self.waypoints[ id2 ]
	if p1 and p2 then
		return p1:addNeighbour( p2 )
	end
	return false
end

function WaypointGraph:disconnectWaypoints( id1, id2 )
	local p1 = self.waypoints[ id1 ]
	local p2 = self.waypoints[ id2 ]
	if p1 and p2 then
		return p1:removeNeighbour( p2 )
	end
	return false
end


function WaypointGraph:rebuildMOAIGraph()
	local graph = MOAIVecPathGraph.new()
	self.pathGraph = graph
	local count = self.nodeCount
	graph:reserveNodes( count )

	for i, wp in ipairs( self.waypoints ) do
		local id = i
		local x, y, z = wp:getWorldLoc()
		graph:setNode( i, x, y, z )
		for neighbour in pairs( wp.neighbours ) do
			local id1 = neighbour.nodeId
			if id1 > id then
				graph:setNeighbours( id, id1, true )
			end
		end
	end

	return graph
end

function WaypointGraph:getMOAIPathGraph()
	return self.pathGraph
end

function WaypointGraph:requestPath( x, y, z )
end