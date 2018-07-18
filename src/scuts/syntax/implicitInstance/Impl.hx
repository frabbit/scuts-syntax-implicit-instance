package scuts.syntax.implicitInstance;

#if (((eval || neko) && display) || macro)

import haxe.macro.Context as C;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ExprTools as ET;

using scuts.macrokit.ArrayApi;

private typedef Dep = { name : String, ct : ComplexType, isThis:Bool };

class Impl {

	static var BUILD_ID = ':scuts.syntax.implicitInstance.Impl';

	static function getDeps (fields:Array<Field>):Array<Dep> {
		function isThis (e:Null<Expr>) {
			return e != null && ET.toString(e) == "this";
		}
		return [for (f in fields) switch f.kind {
			case FieldType.FVar(ct, expr):
				[{ name : f.name, ct : ct, isThis : isThis(expr) }];
			case FieldType.FProp(get, set, ct, expr):
				[{ name : f.name, ct : ct, isThis : isThis(expr) }];
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
			var e = d.isThis ? macro this : macro $i{name};
			macro this.$name = $e;
		}];

		var args:Array<FunctionArg> = [for (d in deps.filter(d -> !d.isThis)) {
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
		var deps = deps.filter(d -> !d.isThis);
		var constructorArgs:Array<Expr> = [for (d in deps) {
			var name = d.name;
			macro $i{name};
		}];

		var params = cl.params;
		var pack = cl.pack;
		var name = cl.name;
		var classParams = cl.params.map( p -> TPType(TPath({ name : p.name, pack : []})));
		var tp:TypePath = { pack: pack, name: name, params: classParams};




		var params = [for (p in cl.params) { name: p.name}];

		var r:Field = if (params.length == 0 && deps.length == 0) {
			var expr = macro @:pos(C.currentPos()) new $tp();
			{
				access: [APublic, AStatic, AFinal],
				name: "instance",
				kind: FieldType.FVar(null, expr),
				pos: C.currentPos(),
				meta: [{ name : ":implicit", pos : C.currentPos() }],
			};
		} else {
			var expr = macro @:pos(C.currentPos()) return new $tp($a{constructorArgs});

			var args:Array<FunctionArg> = [for (d in deps) {
				name : d.name,
				type : d.ct,
			}];
			var f:Function = {
				args: args,
				ret: null,
				expr: expr,
				params: params,
			};

			{
				access: [APublic, AStatic, AInline],
				name: "instance",
				kind: FieldType.FFun(f),
				pos: C.currentPos(),
				meta: [{ name : ":implicit", pos : C.currentPos() }],
			};
		}


		return [r];
	}
	static function removeThis(fields:Array<Field>) {
		function isThis (e:Null<Expr>) {
			return e != null && ET.toString(e) == "this";
		}
		function mkField (f, k) {
			return {
				access: f.access,
				name: f.name,
				kind: k,
				pos : f.pos,
				meta : f.meta,
				doc : f.doc,
			}
		}
		return [for (f in fields) {
			switch f.kind {
				case FieldType.FVar(t, e) if (isThis(e)):
					var kind = FieldType.FVar(t, null);
					mkField(f, kind);
				case FieldType.FProp(get, set, t, e) if (isThis(e)):
					var kind = FieldType.FProp(get, set, t, null);
					mkField(f, kind);
				case _ :
					f;
			}
		}];
	}
	static function addAccessModifier(fields:Array<Field>) {
		return [for (f in fields) {
			var hasPrivate = f.access.any(x -> x.match(APrivate));
			var hasStatic = f.access.any(x -> x.match(AStatic));
			var hasPublic = f.access.any(x -> x.match(APublic));
			var a = if (!hasPrivate && !hasStatic && !hasPublic) f.access.concat([APublic]) else f.access;
			{
				access: a,
				name: f.name,
				kind: f.kind,
				pos : f.pos,
				meta : f.meta,
				doc : f.doc,
			}
		}];
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
			var res = addAccessModifier(fields);
			var deps = getDeps(fields);
			var res = removeThis(res);
			var constructor = createConstructor(deps);
			var instance = createInstance(deps, cl);


			res.concat(instance).concat(constructor);
		} else {
			null;
		}
	}
}

#end