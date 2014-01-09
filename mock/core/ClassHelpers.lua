function _wrapMethod( class, fieldname, methodname, arg, ... )
	local f = loadstring(
			string.format(
				"return function( self, ... ) return self.%s:%s( ... ) end",
				fieldname,
				methodname
			)
			)()
	class[methodname]=f
end

function _wrapMethods( class, fieldname, methodnames )
	for i,n in ipairs(methodnames) do
		_wrapMethod( class, fieldname, n )
	end
end

function _wrapAttrGetter(class,fieldname,attr,methodname)
	local f=loadstring(
		string.format(
			[[return function(self)
								return self.%s:getAttr(%d)
						end
			]]
			,fieldname,attr)
	)
	class[methodname] = f()
end

function _wrapAttrGetterBoolean(class,fieldname,attr,methodname)
	local f=loadstring(
		string.format(
			[[return function(self)
								return self.%s:getAttr(%d) ~= 0
						end
			]]
			,fieldname,attr)
	)
	class[methodname] = f()
end

function _wrapAttrSetter(class,fieldname,attr,methodname)
	local f=loadstring(
		string.format(
			[[return function(self, v )
								return self.%s:setAttr(%d, v )
						end
			]]
			,fieldname,attr)
		)
	class[methodname] = f()
end

function _wrapAttrSeeker(class,fieldname,attr,methodname)
	local f=loadstring(
		string.format(
			[[return function( self, v, t, easeType )
								return self.%s:seekAttr( %d, v, t, easeType )
						end
			]]
			,fieldname,attr)
	)
	class[methodname] = f()
end

function _wrapAttrGetSet( class, fieldname, attr, propertyName)
	_wrapAttrGetter( class, fieldname, attr, 'get'..propertyName )
	_wrapAttrSetter( class, fieldname, attr, 'set'..propertyName )
end