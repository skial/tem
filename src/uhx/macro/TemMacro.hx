package uhx.macro;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import sys.io.Process;
import uhx.macro.klas.Handler;
import uhx.tem.Parser;
import uhx.macro.help.TemCommon;

using Xml;
using Detox;
using StringTools;
using sys.io.File;
using sys.FileSystem;
using uhu.macro.Jumla;
#end

/**
 * ...
 * @author Skial Bainn
 */
@:keep
class TemMacro {

	public static var html:DOMCollection = null;
	
	public static function handler(cls:ClassType, fields:Array<Field>):Array<Field> {
		
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
	}
	
}