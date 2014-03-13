package uhx.macro;

#if macro
import byte.ByteData;
import haxe.Json;
import haxe.Utf8;
import sys.io.Process;
import haxe.macro.Type;
import haxe.macro.Expr;
import uhx.lexer.MarkdownParser;
import uhx.macro.KlasImp;
import haxe.macro.Context;
import haxe.macro.Compiler;
import uhx.macro.help.TemCommon;
import unifill.Utf32;
#end

import Detox;
import uhx.tem.Parser;

#if macro
using sys.io.File;
using sys.FileSystem;
#end

using Detox;
using StringTools;
using haxe.io.Path;

typedef TemConfig = {
	var input:String;
	var output:String;
}

/**
 * ...
 * @author Skial Bainn
 */
class Tem {
	
	private static var config:TemConfig = null;
	
	private static function initialize():Void {
		try {
			KlasImp.initalize();
			KlasImp.CLASS_META.set(':tem', TemMacro.handler);
			
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `uhx.macro.Tem.build()` method.
		}
		
		if (Context.defined('tuli')) {
			uhx.macro.Tuli.registerPlugin('tem', processFiles, finish);
		}
		
		files = [];
		extHook = new Map();
		templates = new Map();
		
		if ( !Context.defined('tuli') && 'config.json'.exists() ) {
			// Load `config.json` if it exists.
			config = Json.parse( File.getContent( 'config.json' ) );
			
			// If `output` is null set it to output provided to the compiler.
			if (config.output != null) {
				config.output = config.output.fullPath();
			} else {
				config.output = Compiler.getOutput();
			}
			
			// If `input` was set, start processing files.
			if (config.input != null) input( config.input = config.input.fullPath() );
		}
	}
	
	/*public static macro function setIndex(path:String):Void {
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
	}*/
	
	public static macro function build():Array<Field> {
		return TemMacro.handler( Context.getLocalClass().get(), Context.getBuildFields() );
	}
	
	public static var files:Array<String>;
	public static var templates:Map<String,String>;
	public static var extHook:Map<String, Array<String->Void>>;
	
	public static var htmlCache:Map<String,DOMCollection> = new Map();
	public static var isPartial:Map<String,Bool> = new Map();
	
	public static function input(path:String) {
		path = '$path/'.normalize();
		
		// Find all files in `path`.
		var allItems = path.readDirectory();
		var index = 0;
		
		// Find all files by recursing through each directory.
		while (allItems.length > index) {
			var item = allItems[index].normalize();
			var location = '$path/$item'.normalize();
			
			if (!location.isDirectory()) {
				files.push( item );
			} else {
				allItems = allItems.concat( location.readDirectory().map( function(d) return '$item/$d'.normalize() ) );
			}
			
			index++;
		}
		
		processFiles(path, allItems);
		
		// Recreate everything in `config.output` directory.
		Context.onAfterGenerate( finish.bind( config.output ) );
	}
	
	public static function output(path:String):Void {
		TemMacro.output = path;
	}
	
	private static function processFiles(path:String, files:Array<String>):Array<String> {
		var filterHTML = function(s:String) return s.extension() == 'html';
		
		for (html in files.filter( filterHTML )) {
			var location = '$path/$html'.normalize();
			var content = location.getContent();
			
			// https://developer.mozilla.org/en-US/docs/Web/HTML/Element
			// Use tidy html5 to force the html into valid xml so Detox
			// on sys platforms can parse it.
			var process = new Process('tidy', [
				// Indent elements.
				'-i', 
				// Be quiet.
				'-q', 
				// Convert to xml.
				'-asxml', 
				// Force the doctype to valid html5
				'--doctype', 'html5',
				// Don't add the tidy html5 meta
				'--tidy-mark', 'n',
				// Keep empty elements and paragraphs.
				'--drop-empty-elements', 'n',
				'--drop-empty-paras', 'n', 
				// Add missing block elements.
				'--new-blocklevel-tags', 
				'article aside audio canvas datalist figcaption figure footer ' +
				'header hgroup output section video details element main menu ' +
				'template shadow nav ruby source',
				// Add missing inline elements.
				'--new-inline-tags', 'bdi content data mark menuitem meter progress rp' +
				'rt summary time',
				// Add missing void elements.
				'--new-empty-tags', 'keygen track wbr',
				// Don't wrap partials in `<html>`, or `<body>` and don't add `<head>`.
				'--show-body-only', 'auto', 
				// Make the converted html easier to read.
				'--vertical-space', 'y', location]);
				
			var parsed = process.stdout.readAll().toString().parse();
			
			process.close();
			
			htmlCache.set(html, parsed);
			if (parsed.first().html().toLowerCase() != '<!doctype html>') {
				isPartial.set(html, true);
			}
		}
		
		return files.filter( function(s) return !filterHTML(s) );
	}
	
	public static function finish(path:String) {
		// Recursively create the directory in `config.output`.
		var createDirectory = function(path:String) {
			if (!path.directory().addTrailingSlash().exists()) {
				
				var parts = path.directory().split('/');
				var missing = [parts.pop()];
				while (!Path.join( parts ).exists()) missing.push( parts.pop() );
				
				missing.reverse();
				
				var directory = Path.join( parts );
				for (part in missing) {
					directory = '$directory/$part'.normalize();
					directory.createDirectory();
				}
				
			}
		}
		
		// Copy anything that is not an html file into output directory.
		for (file in files.filter( function(f) return f.extension() != 'html' )) {
			var input = (config.input + '/$file').normalize();
			var output = (config.output + '/$file').normalize();
			
			createDirectory( output );
			
			File.copy( input, output );
		}
		
		// Recreate the html.
		for (key in htmlCache.keys()) {
			
			var path = (path + '/$key').normalize();
			
			createDirectory( path );
			
			var process = new Process('tidy', [
				// Encode as utf8.
				'-utf8',
				// Be quite.
				'-q',
				// Output as html, as the input is xml.
				'-ashtml',
				// Set the output location.
				'-o', '"$path"',
				// Force the doctype to html5.
				'--doctype', 'html5',
				// Don't add the tidy html5 meta
				'--tidy-mark', 'n',
				//'-f', 'errors_$key.txt',
				// Keep empty elements and paragraphs.
				'--drop-empty-elements', 'n',
				'--drop-empty-paras', 'n', 
				// Add missing block elements.
				'--new-blocklevel-tags', 
				'article aside audio canvas datalist figcaption figure footer ' +
				'header hgroup output section video details element main menu ' +
				'template shadow nav ruby source',
				// Add missing inline elements.
				'--new-inline-tags', 'bdi content data mark menuitem meter progress rp' +
				'rt summary time',
				// Add missing void elements.
				'--new-empty-tags', 'keygen track wbr',
				// Don't wrap partials in `<html>`, or `<body>` and don't add `<head>`.
				'--show-body-only', 'auto', 
				// Make the converted html easier to read.
				'--vertical-space', 'y',
			]);
			
			process.stdin.writeString( htmlCache.get( key ).html() );
			process.close();
			
		}
	}
	
}