package uhx.macro;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import sys.io.Process;
import uhx.tem.Parser;
import uhx.macro.help.TemCommon;
import uhx.macro.klas.Handler;

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
class Tem {
	
	private static macro function initialize():Void {
		try {
			if (!Handler.setup) {
				Handler.initalize();
			}
			
			Handler.CLASS_META.set(':tem', TemMacro.handler);
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `uhx.macro.Tem.build()` method.
		}
	}
	
	public static macro function setIndex(path:String):Void {
		//initialize();
		
		path = Context.resolvePath( path ).fullPath();
		var process:Process = new Process('tidy.exe', ['-i', '-q', '-asxml', '--doctype', 'omit', path]);
		var content = process.stdout.readAll().toString();
		TemMacro.html = content.parse();
		process.close();
		
		// This gets called once macro mode has finished
		Context.onGenerate( function(_) {
			
			var output = Compiler.getOutput();
			
			// path parts
			var pparts = path.split( path.indexOf( '/' ) == -1 ? '\\' : '/' );
			
			// output parts
			var oparts = output.split( output.indexOf( '/' ) == -1 ? '\\' : '/' );
			
			var body:Xml = TemMacro.html.find( 'body' ).collection[0];
			var script:DOMCollection = body.find('script[src*="' + oparts[oparts.length - 1] + '"]');
			
			if (script.length == 0) {
				var script:Xml = Xml.createElement( 'script' );
				
				script.set( 'src', oparts[oparts.length - 1] );
				body.addChild( script );
			} else {
				var src  = script.getNode().attr('src').split( output.indexOf( '/' ) == -1 ? '\\' : '/' );
				
				if (src.length > 1) {
					src.reverse();
					
					for (part in src) {
						oparts[oparts.length - 1] == part ? oparts.pop() : break;
					}
					
					oparts.push( src.pop() );
				}
			}
			
			// replaces `output` filename with `path` file name
			oparts[oparts.length - 1] = pparts[pparts.length - 1];
			
			var process:Process = new Process('tidy.exe', ['-utf8', '-q', '-ashtml', '-o', oparts.join( '/' ), '--doctype', 'html5']);
			process.stdin.writeString( TemMacro.html.html() );
			process.close();
			
		} );
	}
	
	public static macro function build():Array<Field> {
		return TemMacro.handler( Context.getLocalClass().get(), Context.getBuildFields() );
	}
	
}