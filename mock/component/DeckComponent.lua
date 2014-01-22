module 'mock'

CLASS: DeckComponent( RenderComponent )
	:MODEL{
		Field 'deck'  :asset('deck2d\\..*')        :getset('Deck'),
		Field 'index' :int() :range(0) :getset( 'Index' );
	}

--------------------------------------------------------------------
function DeckComponent:__init()
	self._moaiDeck = false
	self.prop = MOAIProp.new()
	self:setBlend('normal')
end

function DeckComponent:onAttach( entity )
	entity:_attachProp( self.prop )
end

function DeckComponent:onDetach( entity )
	entity:_detachProp( self.prop )
end

--------------------------------------------------------------------
function DeckComponent:getMoaiProp()
	return self.prop
end

--------------------------------------------------------------------
function DeckComponent:setDeck( deckPath )
	self.deckPath = deckPath
	local deck = mock.loadAsset( deckPath )
	self._moaiDeck = deck
	self.prop:setDeck( deck )
end

function DeckComponent:getDeck( deckPath )
	return self.deckPath	
end

function DeckComponent:getMoaiDeck()
	return self._moaiDeck
end

function DeckComponent:setIndex( i )
	self.prop:setIndex( i )
end

function DeckComponent:getIndex()
	return self.prop:getIndex()
end

function DeckComponent:setBlend( b )
	self.blend = b
	setPropBlend( self.prop, b )
end

function DeckComponent:getBounds()
	return self.prop:getBounds()
end

function DeckComponent:getTransform()
	return self.prop
end

function DeckComponent:setLayer( layer )
	layer:insertProp( self.prop )
end

--------------------------------------------------------------------

function DeckComponent:setScissorRect( s )
	self.prop:setScissorRect( s )
end

--------------------------------------------------------------------
function DeckComponent:drawBounds()
	GIIHelper.setVertexTransform( self.prop )
	local x1,y1,z1, x2,y2,z2 = self.prop:getBounds()
	MOAIDraw.drawRect( x1,y1,x2,y2 )
end

--------------------------------------------------------------------
function DeckComponent:inside( x, y, z, pad )
	return self.prop:inside( x,y,z, pad )
end

--------------------------------------------------------------------
function DeckComponent:setVisible( f )
	self.prop:setVisible( f )
end

function DeckComponent:isVisible()
	return self.prop:getAttr( MOAIProp.ATTR_VISIBLE ) ~= 0
end

wrapWithMoaiPropMethods( DeckComponent, ':getMoaiProp()' )
