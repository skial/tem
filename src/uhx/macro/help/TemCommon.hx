package uhx.macro.help;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import uhx.tem.Parser;

using uhu.macro.Jumla;
using haxe.macro.Context;

/**
 * ...
 * @author Skial Bainn
 */
class TemCommon {
	
	public static var PreviousTem:String = 'Tem';
	public static var TemPlateExprs:Array<Expr> = [];
	public static var TemPlateFields:Array<Field> = [];
	public static var TemPlateCache:Map<String, Expr> = new Map<String, Expr>();
	
	public static var TemClass(get, never):TypeDefinition;
	
	private static function get_TemClass() return macro class TemHolder {
		
		public var temDom:dtx.DOMCollection = null;
		
		private function temSetup(fragment:dtx.DOMCollection):Void {
			temDom = fragment;
			uhx.tem.Parser.cls = $i { Context.getLocalClass().get().name };
			uhx.tem.Parser.instance = this;
			uhx.tem.Parser.fields = std.Type.getInstanceFields( uhx.tem.Parser.cls );
			uhx.tem.Parser.process( fragment, $v { Context.getLocalClass().get().name } );
		}
		
	}
	
	public static var tem(get, never):TypeDefinition;
	
	private static function get_tem():TypeDefinition {
		return {
			pack: [],
			name: 'Tem' + Date.now().getTime(),
			pos: Context.currentPos(),
			meta: [ { name: ':native', params: [macro 'Tem'], pos: Context.currentPos() } ],
			params: [],
			isExtern: false,
			kind: TDClass(),
			fields: []
		}
	}
	
	public static var plate(get, never):Field;
	
	private static function get_plate():Field {
		return {
			name: 'plate',
			access: [APublic, AStatic],
			kind: FFun( {
				args: [],
				ret: macro: Void,
				expr: macro {
					
				},
				params: [],
			} ),
			pos: Context.currentPos()
		};
	}
	
}