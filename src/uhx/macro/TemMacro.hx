package uhx.macro;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import sys.io.Process;
import uhx.macro.KlasImp;
import uhx.tem.Parser;
import uhx.macro.help.TemCommon;

using Xml;
using Lambda;
using Detox;
using StringTools;
using sys.io.File;
using sys.FileSystem;
using haxe.macro.Tools;
#end

/**
 * ...
 * @author Skial Bainn
 */
@:keep
class TemMacro {
	
	public static var input:String = '';
	public static var output:String = Compiler.getOutput();
	//public static var html:DOMCollection = null;
	
	/*public static function handler(cls:ClassType, fields:Array<Field>):Array<Field> {
		
		if (Context.defined( 'display' )) return fields;
		
		if (!cls.isStatic()) {
			
			if (fields.exists('new')) {
				
				var _ts = TemCommon.TemSetup;
				fields.push( _ts );
				
				var _new = fields.get('new');
				
				switch (_new.kind) {
					case FFun(m):
						m.args.push( 'fragment'.mkArg( macro: dtx.DOMCollection, true ) );
						
						switch (m.expr.expr) {
							case EBlock( es ):
								es.unshift( macro if (fragment != null) TemSetup( fragment ) );
								
							case _:
						}
						
					case _:
				}
				
			}
			
		} else {
			
			Context.error( '${cls.path()} requires a constructor.', cls.pos );
			
		}
		
		if (!fields.exists( TemCommon.TemDOM.name )) fields.push( TemCommon.TemDOM );
		
		Parser.cls = cls;
		Parser.fields = fields;
		Parser.process( html.find('.${cls.name}'), cls.name );
		
		if (TemCommon.TemPlateExprs.length > 0) {
			
			var ndef = TemCommon.tem;
			var nplate = TemCommon.plate;
			
			nplate.body( { expr:EBlock( TemCommon.TemPlateExprs ), pos: nplate.pos } );
			
			ndef.fields.push( nplate );
			
			Context.defineType( ndef );
			Compiler.exclude( TemCommon.PreviousTem );
			TemCommon.PreviousTem = ndef.path();
			
		}
		
		return fields;
	}*/
	
	public static function handler(cls:ClassType, fields:Array<Field>):Array<Field> {
		if (!Context.defined( 'display' )) {
			// Treat this class as static?
			var isStatic = !fields.exists( function(f) return f.name == 'new' );
			
			if (!isStatic) {
				
				// ---
				// Modify the constructor to take a DOMCollection
				// ---
				
				var ctor = fields.filter( function(f) return f.name == 'new' )[0];
				switch (ctor.kind) {
					case FFun(m):
						m.args.push( { name:'fragment', opt:true, type:macro:DOMCollection } );
						
						switch (m.expr.expr) {
							case EBlock( exprs ):
								exprs.unshift( macro if (fragment != null) temSetup( fragment ) );
								
							case _:
						}
						
					case _:
				}
				
				// Insert new fields
				for (field in TemCommon.TemClass.fields) {
					field.meta = [];
					fields.push( field );
				}
				
			}
			
			// Now pre process each html file based only on the current class.
			for (html in Tem.htmlCache) {
				Parser.cls = cls;
				Parser.fields = fields;
				Parser.process( html.find('.${cls.name}'), cls.name );
			}
			
			// Recreate `Tem.plate()` each and every time.
			if (TemCommon.TemPlateExprs.length > 0) {
				
				var ndef = TemCommon.tem;
				var nplate = TemCommon.plate;
				
				switch (nplate.kind) {
					case FFun(m): m.expr = macro { $a { TemCommon.TemPlateExprs } };
					case _:
				}
				
				ndef.fields.push( nplate );
				
				Context.defineType( ndef );
				Compiler.exclude( TemCommon.PreviousTem );
				TemCommon.PreviousTem = ndef.pack.toDotPath( ndef.name );
				
			}
			
		}
		
		return fields;
	}
	
	private static var counter:Int = 0;
	
	public static function genericBuild():Type {
		var type = Context.getLocalType();
		
		switch (type) {
			case TInst(_, params):
				type = params[0];
				
				switch (type) {
					case TInst(rcls, params):
						var cls = rcls.get();
						var ifields = cls.fields.get();
						var sfields = cls.statics.get();
						
						var ctype = Context.toComplexType( type );
						var others:Array<Array<Field>->Void> = [];
						var fields:Array<Field> = [for (field in ifields) if (field.isPublic) {
							var _type = field.type.applyTypeParameters(cls.params, params);
							{ 	
								name: field.name,
								access: [APublic, switch(field.kind) { case FMethod(_):AInline; case _:APublic; } ],
								kind: switch (field.kind) {
									case FVar(_, _): 
										others.push( function(f) {
											f.push( {
												name: 'get_${field.name}',
												access: [APrivate,AInline],
												kind: FFun( { args:[], ret:_type.toComplexType(), expr:Context.parse( 'return this.${field.name}', field.pos ) } ),
												pos: field.pos,
											} );
										} );
										FProp('get', 'never', _type.toComplexType(), null);
										
									case FMethod(k): 
										var typed = field.expr();
										var fargs:Array<FunctionArg> = [];
										var nargs:Array<String> = [];
										var ret:Type = null;
										
										if (typed != null) switch (typed.expr) {
											case TFunction(f):
												fargs = [for (arg in f.args) {
													var _t = try arg.v.t.applyTypeParameters(cls.params, params) catch (_e:Dynamic) arg.v.t;
													{ name:arg.v.name, type:_t.toComplexType() };
												} ];
												nargs = [for (arg in f.args) arg.v.name];
												ret = f.t;
												
											case _:
										} else switch (field.type) {
											case TFun(a, r):
												fargs = [for (aa in a) { name:aa.name, type:aa.t.applyTypeParameters(cls.params, params).toComplexType() } ];
												nargs = [for (aa in a) aa.name];
												ret = r;
												
											case _:
										}
										
										var args = nargs.join(",");
										ret = ret.applyTypeParameters(cls.params, params);
										
										FFun( {
											args: fargs,
											ret: ret.toComplexType(),
											expr: macro {
												return $e { Context.parse( 'this.${field.name}($args)', field.pos ) };
											},
											params: [for (param in field.params) {
												{ name: param.name, params: [{name:param.t.getClass().name, params:[]}] }
											}],
										} );
								},
								pos: field.pos,
							}
						}];
						
						for (other in others) other(fields);
						
						var td = {
							name: 'Hijacked${cls.name}_$counter',
							pack: [],
							pos: cls.pos,
							params: [],
							kind: TDAbstract( ctype, [ctype], [ctype] ),
							fields: fields,
						}
						
						Context.defineType( td );
						type = Context.getType( td.name );
						
						counter++;
						
					case _:
				}
				
			case _:
		}
		
		return type;
	}
	
}