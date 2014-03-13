package uhx.tem;

import haxe.rtti.Meta;
import uhx.tem.help.TemHelp;
#if macro
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
//import uhx.macro.help.Hijacked;
import uhx.macro.help.TemCommon;
import haxe.macro.ComplexTypeTools;
#end

using Xml;
using Detox;
using Lambda;
using StringTools;
#if macro
//using uhu.macro.Jumla;
using haxe.macro.Context;
using haxe.macro.Tools;
#end

typedef Fields = #if macro Array<Field> #else Array<String> #end;

/**
 * ...
 * @author Skial Bainn
 */
class Parser {
	
	public static var current:String = null;
	public static var fields:Fields = null;
	public static var cls: #if macro ClassType #else Class<Dynamic> #end;
	
	#if js
	public static var instance:Dynamic = null;
	#end

	public static function process(html:DOMCollection, name:String, child:Bool = false) {
		var invalid = ['class', 'id'];
		
		for (ele in html) {
			
			#if macro
			if (!child) {
				
				var local = Context.getLocalClass().get();
				//var ttype = local.path().getType().follow();
				var tpath = { pack: local.pack, name: local.name };
				var ttype = local.pack.toDotPath(local.name).getType().follow();
				var ctype = ttype.toComplexType();
				
				if (fields.exists( function(f) return f.name == 'new' )) {
					//TemCommon.TemPlateExprs.push( { expr: ENew( std.Type.enumParameters(ctype)[0], [ macro @:fragment Detox.find( $v { '.' + name } ) ] ), pos: cls.pos } );
					TemCommon.TemPlateExprs.push( macro new $tpath(@:fragment Detox.find($v { '.' + name } )) );
				}
			}
			#end
			
			for (attr in ele.attributes#if macro () #end) {
				
				var _attr = 
				#if macro 
				attr;
				#else 
				attr.nodeName;
				#end
				
				var isData = _attr.startsWith('data-');
				
				switch (_attr) {
					case _ if (isData && invalid.indexOf( _attr ) == -1):
						processEle( _attr.replace('data-', '').replace('-', '_'), ele );
						
					case _ if (!isData && invalid.indexOf( _attr ) == -1):
						processAttr( _attr.replace('-', '_'), ele );
						
					case _:
				}
				
			}
			
			if (ele.attr('class') != '' && !ele.hasClass(name)) continue;
			
			if (ele.children( true ).length > 0) {
				
				process( ele.children( true ), name, true );
				
			}
			
		}
		
		return html;
	}
	
	#if macro
	private static function setterExpr(type:Type):Expr {
		var pos = Context.currentPos();
		var result:Expr = Context.parse( 'uhx.tem.help.TemHelp.toDefault', pos );
		var iterable = 'Iterable'.getType();
		
		switch ( type.follow() ) {
			case TInst(t, p):
				switch( t.get().name ) {
					case 'Array' | _ if (type.unify( iterable ) && p[0] != null):
						result = setterExpr( p[0] );
					
					case _ if (TemHelp.toMap.exists( t.get().name )):
						result = Context.parse( 'uhx.tem.help.TemHelp.to${t.get().name}', pos );
						
					case _:
						
				}
				
			case TAbstract(t, p):
				var abst = t.get();
				
				switch (abst.name) {
					case _ if (abst.type.unify( iterable ) && p[0] != null):
						result = setterExpr( p[0] );
					
					case _ if (TemHelp.toMap.exists( abst.name )):
						result = Context.parse( 'uhx.tem.help.TemHelp.to${abst.name}', pos );
						
					case _:
						
				}
				
			case _:
				#if debug
				trace( type.follow() );
				#end
		};
		
		return result;
	}
	
	public static function processDOM(name:String, ele:DOMNode, attribute:Bool = false) {
		if (fields.exists( function(f) return f.name == name )) {
			var field = fields.filter( function(f) return f.name == name )[0];
			var isStatic = field.access.indexOf( AStatic ) > -1;
			var prefix = attribute ? 'TEMATTR' : 'TEMDOM';
			var domName = '${prefix}_$name';
			var attName = (attribute?'':'data-') + name;
			var pos = Context.currentPos();
			var iterable = 'Iterable'.getType();
			
			switch (field.kind) {
				case FVar(t, e):
					
					var type = t.toType();
					
					if (type.unify( iterable )) {
						/*field.meta.push( 'isIterable'.mkMeta() );
						switch ( type ) {
							case TInst(_t, _p):
								
								switch (_t.get().name) {
									case 'Array':
										var td:TypeDefinition = Hijacked.array;
										var aw:Field = td.fields.get( 'arrayWrite' );
										var m:Function = aw.getMethod();
										
										switch (m.expr.expr) {
											case EBlock( es ):
												m.expr = { expr: EBlock( 
													// dirty little trick, in every non static method, add `var ethis = this`
													// so when `arrayWrite` gets inlined it references the correct instance.
													// ^ This is done in by EThis.hx as part of uhx.macro.klas.Handler.hx ^
													[ macro $e { Context.parse( 'untyped uhx.tem.help.TemHelp.setCollectionIndividual(value, key, ethis.get_$domName(), ${setterExpr( t.toType() ).printExpr()}, ${attribute?attName:null})', pos ) } ]
													.concat( es ) 
												), pos: aw.pos };
												
											case _:
										}
										
										Context.defineType( td );
										
										t = TPath( {
											pack: td.pack,
											name: td.name,
											params: [ TPType( _p[0].toComplexType() ) ],
										} );
										
									case _:
										
								}
								
							case _:
								
						}*/
						
					}
					
					var types = [];
					while (true) {
						
						types.push( macro $v { type.follow().getName().split('.').pop() } );
						var params = params(type);
						
						if (params.length > 0) {
							type = params[0];
						} else {
							break;
						}
						
					}
					
					field.meta.push( { name: 'type', params: types, pos: field.pos } );
					
					if (!isStatic) {
						
						field.kind = FProp('default', 'set', t, e);
						
						var call = Context.parse('uhx.tem.help.TemHelp.set' + (type.unify( iterable ) ? 'Collection' : 'Individual'), pos);
						var setter = 'set_${field.name}', getter = 'get_${field.name}';
						// Create helper fields for this instance class.
						var newFields = (macro class {
							// Cache the dom element.
							@:isVar public var $domName(get, null):dtx.DOMNode;
							
							public function $setter(v:$t) {
								$i { name } = v; 
								$call( v, $i { domName }, $e{ setterExpr( type ) }, $v { attribute? attName :null } );
								return v;
							}
							
							public function $getter() {
								if ($i { domName } == null) {
									$i { domName } = dtx.collection.Traversing.find(temDom, '[$attName]').getNode();
								}
								return $i { domName };
							}
						}).fields;
						
						// Insert helper fields into current instance class.
						for (newField in newFields) {
							newField.meta = [];
							fields.push( newField );
						}
						
					} else {
						
						switch (e.expr) {
							// Find constant values and insert them directly into the dom.
							case EConst(CInt(v)), EConst(CFloat(v)), EConst(CString(v)): 
								if (attribute) {
									ele.setAttr( attName, '$v' );
								} else {
									ele.setText( '$v' );
								}
								
							case _:
						}
						
					}
					
				case _:
					
			}
			
		}
		
	}
	
	public static inline function processEle(name:String, ele:DOMNode) {
		processDOM( name, ele );
	}
	
	public static inline function processAttr(name:String, ele:DOMNode) {
		processDOM( name, ele, true );
	}
	
	private static function params(type:Type):Array<Type> return switch (type) {
		case TInst(_, p): p;
		case TEnum(_, p): p;
		case TType(_, p): p;
		case TAbstract(_, p): p;
		case _: [];
	}
	#else
	public static function processDOM(name:String, ele:DOMNode, attribute:Bool = false) {
		
		if (fields.indexOf( name ) > -1) {
			
			var hasSetter = fields.indexOf( 'set_$name' ) > -1;
			var types:Array<String> = Reflect.field( Meta.getFields( cls ), name ).type;
			var type = types.shift();
			if (hasSetter && TemHelp.parserMap.exists( type )) {
				
				var result = TemHelp.parserMap.get( type )( name, ele, attribute, types.copy() );
				Reflect.setField(instance, name, result);	// will likely need to add a boolean for setters to check
				
			} else {
				trace( 'Cant find parser!' );
				trace( name );
				trace( types );
			}
			
		}
		
	}
	
	public static inline function processEle(name:String, ele:DOMNode) {
		processDOM( name, ele );
	}
	
	public static inline function processAttr(name:String, ele:DOMNode) {
		processDOM( name, ele, true );
	}
	#end
	
}