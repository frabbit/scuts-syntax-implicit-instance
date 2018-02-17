package scuts.syntax.implicitInstance;

#if macro

import haxe.macro.Context as C;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ExprTools as ET;

using scuts.macrokit.ArrayApi;

private typedef Dep = { name : String, ct : ComplexType };

class Impl {

	static var BUILD_ID = 'scuts.syntax.implicitInstance.Impl';

	static function getDeps (fields:Array<Field>):Array<Dep> {
		return [for (f in fields) switch f.kind {
			case FieldType.FVar(ct, expr):
				[{ name : f.name, ct : ct }];
			case FieldType.FProp(get, set, ct, expr):
				[{ name : f.name, ct : ct }];
			case _ :
				[];
		}].flatten();
	}

	static function isApplied (cl:ClassType, key:String) {
		return cl.meta.has(key);
	}

	static function createConstructor (deps:Array<Dep>):Array<Field> {
		var assigns:Array<Expr> = [for (d in deps) {
			var name = d.name;
			macro this.$name = $i{name};
		}];

		var args:Array<FunctionArg> = [for (d in deps) {
			name : d.name,
			type : null,
		}];

		var f:Function = {
			args: args,
			ret: null,
			expr: macro $b{assigns},
		};

		var r:Field = {
			name: "new",
			kind: FieldType.FFun(f),
			pos: C.currentPos(),
		};
		return [r];
	}

	static function createInstance (deps:Array<Dep>, cl:ClassType):Array<Field> {
		var constructorArgs:Array<Expr> = [for (d in deps) {
			var name = d.name;
			macro $i{name};
		}];

		var params = cl.params;
		var pack = cl.pack;
		var name = cl.name;
		var classParams = cl.params.map( p -> TPType(TPath({ name : p.name, pack : []})));
		var tp:TypePath = { pack: pack, name: name, params: classParams};

		var expr = macro return new $tp($a{constructorArgs});

		var args:Array<FunctionArg> = [for (d in deps) {
			name : d.name,
			type : d.ct,
		}];

		var f:Function = {
			args: args,
			ret: null,
			expr: expr,
			params: [for (p in cl.params) { name: p.name}],
		};

		var r:Field = {
			access: [APublic, AStatic],
			name: "instance",
			kind: FieldType.FFun(f),
			pos: C.currentPos(),
			meta: [{ name : ":implicit", pos : C.currentPos() }],
		};

		return [r];
	}

	public static function build () {
		var cl = C.getLocalClass();
		if (cl == null) {
			C.fatalError("local class is null", C.currentPos());
		}
		var cl = cl.get();
		var applied = isApplied(cl, BUILD_ID);

		return if (!applied) {
			var fields = C.getBuildFields();
			cl.meta.add(BUILD_ID, [], C.currentPos());
			var res = fields.copy();
			var deps = getDeps(fields);
			var constructor = createConstructor(deps);
			var instance = createInstance(deps, cl);
			res.concat(instance).concat(constructor);
		} else {
			null;
		}
	}
}

#end