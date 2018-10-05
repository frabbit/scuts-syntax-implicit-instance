package scuts.syntax.implicitInstance;

#if (((eval || neko) && display) || macro)

import haxe.macro.Context as C;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ExprTools as ET;

using scuts.macrokit.ArrayApi;

private typedef Dep = { name : String, ct : ComplexType, isThis:Bool };

private typedef RiskyInit = { name : String, ct : ComplexType, expr : Expr };

class Impl {

	static var BUILD_ID = ':scuts.syntax.implicitInstance.Impl';

	static function getDeps (fields:Array<Field>):Array<Dep> {
		function isThis (e:Null<Expr>) {
			return e != null && ET.toString(e) == "this";
		}

		function ignore (f) return f.meta != null && f.meta.filter(f -> f.name == ":ignore").length > 0;

		return [for (f in fields) if (!ignore(f)) switch f.kind {
			case FieldType.FVar(ct, expr) if (expr == null || isThis(expr)):
				[{ name : f.name, ct : ct, isThis : isThis(expr) }];
			case FieldType.FProp(get, set, ct, expr) if (expr == null || isThis(expr)):
				[{ name : f.name, ct : ct, isThis : isThis(expr) }];
			case _ :
				[];
		}].flatten();
	}

	static function getRiskyInits (fields:Array<Field>):Array<RiskyInit> {
		function isThis (e:Null<Expr>) {
			return e != null && ET.toString(e) == "this";
		}

		function ignore (f) return f.meta != null && f.meta.filter(f -> f.name == ":ignore").length > 0;

		return [for (f in fields) switch f.kind {
			case FieldType.FVar(ct, expr) if (expr != null && !isThis(expr)):
				[{ name : f.name, ct : ct, expr : expr }];
			case FieldType.FProp(get, set, ct, expr) if (expr != null && !isThis(expr)):
				[{ name : f.name, ct : ct, expr : expr }];
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
			access: [],
			kind: FieldType.FFun(f),
			pos: C.currentPos(),
		};
		return [r];
	}

	static function createInstance (deps:Array<Dep>, cl:ClassType, riskyInits:Array<RiskyInit>):Array<Field> {
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

		var r:Array<Field> = switch [params.length, deps.length, riskyInits.length] {
			case [0, 0, 0]:
				//trace("OPT1: " + cl.module + "." + cl.name + ":");
				//var newExpr = { expr : ENew(tp, [])}
				var expr = macro @:pos(C.currentPos()) new $tp();
				[{
					access: [APublic, AStatic, AFinal],
					name: "instance",
					kind: FieldType.FVar(null, expr),
					pos: C.currentPos(),
					meta: [{ name : ":implicit", pos : C.currentPos() }],
				}];
			case [_, 0, risky]:

				// if we don't have dependencies, but we have type parameters we can reuse the same instance
				// this instance should replace all type params by monos, which are never unified.
				// EitherFunctor<L> becomes EitherFunctor<Mono>
				var doLazy = risky > 0;
				var classParams = cl.params.map( p -> TPType(TPath({ name : "Mono", pack : ["scuts", "implicit"]})));
				var tp2:TypePath = { pack: pack, name: name, params: classParams};
				var expr = macro @:pos(C.currentPos()) new $tp2();
				var instance = {
					access: [AStatic].concat(doLazy ? [] : [AFinal]),
					name: "instance1",
					kind: FieldType.FVar(null, doLazy ? null : expr),
					pos: C.currentPos(),
					meta: [],
				};

				var expr = if (doLazy) {
					macro @:pos(C.currentPos()) return { if (instance1 == null) instance1 = $expr; instance1; }
				}
				else {
					macro @:pos(C.currentPos()) return instance1;
				}


				var args:Array<FunctionArg> = [for (d in deps) {
					name : d.name,
					type : d.ct,
				}];
				var f:Function = {
					args: args,
					ret: TPath(tp),
					expr: expr,
					params: params,
				};
				//trace(haxe.macro.ComplexTypeTools.toString(TPath(tp)));
				var instanceFunc = {
					access: [APublic, AStatic].concat(doLazy ? [] : [AInline]),
					name: "instance",
					kind: FieldType.FFun(f),
					pos: C.currentPos(),
					meta: [{ name : ":implicit", pos : C.currentPos() }],
				};

				[instance, instanceFunc];
			case [_, _, _]:
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

				[{
					access: [APublic, AStatic, AInline],
					name: "instance",
					kind: FieldType.FFun(f),
					pos: C.currentPos(),
					meta: [{ name : ":implicit", pos : C.currentPos() }],
				}];
		}
		return r;
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

			var hasConstructor = fields.filter(f -> f.name == "new").length >= 1;

			cl.meta.add(BUILD_ID, [], C.currentPos());
			var res = addAccessModifier(fields);
			var deps = getDeps(fields);
			var riskyInits = getRiskyInits(fields);
			var res = removeThis(res);
			var constructor = if (!hasConstructor) createConstructor(deps) else [];
			var instance = createInstance(deps, cl, riskyInits);


			res.concat(instance).concat(constructor);
		} else {
			null;
		}
	}
}

#end