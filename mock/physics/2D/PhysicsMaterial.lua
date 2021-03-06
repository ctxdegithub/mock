module 'mock'

---------------------------------------------------------------------
--Material
--------------------------------------------------------------------
CLASS: PhysicsMaterial ()
	:MODEL{
		Field 'tag' :string();
		'----';
		Field 'density';
		Field 'restitution';
		Field 'friction';
		'----';
		Field 'group'        :int();
		Field 'categoryBits' :int() :widget( 'bitmask16' );
		Field 'maskBits'     :int() :widget( 'bitmask16' );
		'----';
		Field 'isSensor'     :boolean();
		'----';
	}

function PhysicsMaterial:__init()
	self.density      = 1
	self.restitution  = 0
	self.friction     = 0
	self.isSensor     = false
	self.group        = 0
	self.categoryBits = 1
	self.maskBits     = 0xffffffff
end

function PhysicsMaterial:clone()
	local m = PhysicsMaterial()
	m.density      = self.density
	m.restitution  = self.restitution
	m.friction     = self.friction
	m.isSensor     = self.isSensor
	m.group        = self.group
	m.categoryBits = self.categoryBits
	m.maskBits     = self.maskBits
	return m
end

--------------------------------------------------------------------
local DefaultMaterial = PhysicsMaterial()

function getDefaultPhysicsMaterial()
	return table.simplecopy(DefaultMaterial)
end

--------------------------------------------------------------------
local function loadPhysicsMaterial( node )
	local data   = mock.loadAssetDataTable( node:getObjectFile('def') )
	local config = mock.deserialize( nil, data )	
	return config
end

registerAssetLoader( 'physics_material', loadPhysicsMaterial )
