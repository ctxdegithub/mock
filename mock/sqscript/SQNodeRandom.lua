module 'mock'

--------------------------------------------------------------------
CLASS: SQNodeRandomBranch ( SQNodeBranch )
	:MODEL{
		Field 'name'   :string();
		Field 'weight' :int();
}

function SQNodeRandomBranch:__init()
	self.name = 'Random Branch'
	self.weight = 1
end

function SQNodeRandomBranch:exit( state, env )
	state:setJumpTarget( self.parentNode:getNextSibling() )
	return 'jump'
end

function SQNodeRandomBranch:getRichText()
	return string.format( '<branch>%s</branch> weight:<number>%d</number>', self.name, self.weight )
end

function SQNodeRandomBranch:getIcon()
	return 'sq_node_branch'
end

function SQNodeRandomBranch:isBuiltin()
	return true
end

--------------------------------------------------------------------
CLASS: SQNodeRandom ( SQNodeGroup )
	:MODEL{}

function SQNodeRandom:__init()
	self.brancheProbList = {}
	self.name = 'RandomGroup'
end

function SQNodeRandom:acceptSubNode( name )
	return name == 'random_branch'
end

function SQNodeRandom:getIcon()
	return 'sq_node_random'
end

function SQNodeRandom:getRichText()
	return string.format( '<cmd>RANDOM</cmd> [ <group>%s</group> ]', self.name )
end

function SQNodeRandom:enter( state, env )
	local jumpTo = probselect( self.brancheProbList )
	if jumpTo then
		state:setJumpTarget( jumpTo )
		return 'jump'
	else
		return true
	end
end

function SQNodeRandom:build()
	local l = {}
	for i,child in ipairs( self.children ) do
		local entry = { child.weight, child }
		l[i] = entry
	end
	self.brancheProbList = l
end

registerSQNode( 'random',         SQNodeRandom  )
registerSQNode( 'random_branch',  SQNodeRandomBranch  )