package scuts.syntax.implicitInstance;

import haxe.macro.TypeTools;
#if (((eval || neko) && display) || macro)

import haxe.macro.Context as C;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ExprTools as ET;

using scuts.macrokit.ArrayApi;

private typedef Dep = { name : String, ct : ComplexType, isThis:Bool, isConstraint:Bool };

private typedef RiskyInit = { name : String, ct : ComplexType, expr : Expr };

class Impl {

	static var isConstraint = (f:Field) -> f.name == "_";
	static var BUILD_ID = ':scuts.syntax.implicitInstance.Impl';

	static function getDeps (fields:Array<Field>):Array<Dep> {
		function isThis (e:Null<Expr>) {
			return e != null && ET.toString(e) == "this";
		}

		function ignore (f) return f.meta != null && f.meta.filter(f -> f.name == ":ignore").length > 0;



		return [for (f in fields) if (!ignore(f)) switch f.kind {
			case FieldType.FVar(ct, expr) if (expr == null || isThis(expr)):
				[{ name : f.name, ct : ct, isThis : isThis(expr), isConstraint: isConstraint(f) }];
			case FieldType.FProp(get, set, ct, expr) if (expr == null || isThis(expr)):
				[{ name : f.name, ct : ct, isThis : isThis(expr), isConstraint: isConstraint(f) }];
			case _ :
				[];
		}].flatten();
	}

	static function hasTypeParam (t:Type, base:ClassType) {
		var pack = base.pack.join(".");
		var baseName = base.pack.length > 0 ? pack + "." + base.name : base.name;

		function loop(t) return switch C.follow(t) {
			case TInst(_.get() => cl, params):
				switch cl.kind {
					case KTypeParameter(_):
						cl.pack.join(".") == baseName;
					case _:
						ArrayApi.any(params, loop);
				}
			case TEnum(_, params):
				ArrayApi.any(params, loop);
			case TType(_, params):
				ArrayApi.any(params, loop);
			case TAbstract(_, params):
				ArrayApi.any(params, loop);
			case TFun(args, ret):
				ArrayApi.any(args, a -> loop(a.t)) || loop(ret);
			case _:
				false;
		}
		return loop(t);
	}

	static function getInterfaceVars (base:ClassType):Array<Field> {

		function get(cl:Type) {
			return switch cl {
				case TInst(x, params1):
					var allFields = x.get().fields.get();

					[for (a in allFields) if (a.kind.match(FVar(_))) {


						var t3 = TypeTools.applyTypeParameters(a.type, x.get().params, params1);

						var hasCallSiteTypeParam = hasTypeParam(t3, base);

						var ct = TypeTools.toComplexType(t3);
						/*
						function loop(ct) {
							if (ct == null) return ct;
							function mapKind(k:FieldType) {
								return switch k {
									case FVar(t, e): FieldType.FVar(loop(t), e);
									case FProp(get, set, t, e): FieldType.FProp(get, set, loop(t), e);
									case FFun(f):
										FieldType.FFun({
											args: f.args.map(a -> { meta: a.meta, name:a.name, opt:a.opt, type:loop(a.type), value: a.value }),
											expr: f.expr,
											params: f.params,
											ret: loop(f.ret),
										});
								}
							}
							function mapFields (fields:Array<Field>) {
								return fields.map(x -> {
									access: x.access,
									doc: x.doc,
									kind: mapKind(x.kind),
									meta: x.meta,
									name: x.name,
									pos: x.pos,
								});
							}
							function mapTypeParam (tp:TypeParam) {
								return switch tp {
									case TPType(ct): TPType(loop(ct));
									case TPExpr(e): tp;
								}
							}
							function mapTypePath (p:TypePath) {
								var name = p.name == "-In" ? "-In" : p.name;
								var sub = p.name == "-In" ? null : p.sub;

								return {
									name: name,
									pack: p.pack,
									params: p.params.map(mapTypeParam),
									sub: sub,
								}
							}
							return switch ct {
								case TPath(p):
									TPath(mapTypePath(p));
								case TFunction(args, ret):
									ComplexType.TFunction(args.map(loop), loop(ret));
								case TAnonymous(fields):
									ComplexType.TAnonymous(mapFields(fields));
								case TExtend(p, fields): TExtend(p.map(mapTypePath), mapFields(fields));
								case TParent(p): TParent(loop(p));
								case TNamed(n,ct): TNamed(n, loop(ct));
								case TOptional(t): TOptional(loop(t));
								case TIntersection(tl): TIntersection(tl.map(loop));
							}
						}
						var ct2 = loop(ct);
						*/
						/*
						if (base.name == "MonadZeroArray") {
							trace(haxe.macro.ComplexTypeTools.toString(ct));
							trace(haxe.macro.ComplexTypeTools.toString(ct2));

						}
						*/
						//var ct = ct2;

						// trace(ct);

						var name = a.name;


						var c = hasCallSiteTypeParam ?
							macro class X{
								final $name:$ct;
							}
						: 	macro class X {
								final $name:$ct = _;
							}
						c.fields[0];
					}];
				case _: [];
			}
		}
		var all = [for ( i in base.interfaces) {
			var it = TInst(i.t, i.params);
			get(it);
		}];

		var all1 = [for (a in all) for (x in a) x];
		// trace(all1);

		return all1;
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
		var assigns:Array<Expr> = [for (d in deps) if (!d.isConstraint) {
			var name = d.name;
			var e = d.isThis ? macro this :  macro $i{name};
			macro this.$name = $e;
		}];

		var args:Array<FunctionArg> = [for (d in deps.filter(d -> !d.isThis && !d.isConstraint)) {
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
			access: assigns.length == 0 ? [AInline] : [],
			kind: FieldType.FFun(f),
			pos: C.currentPos(),
		};
		return [r];
	}

	static function createInstance (deps:Array<Dep>, cl:ClassType, riskyInits:Array<RiskyInit>):Array<Field> {
		var deps = deps.filter(d -> !d.isThis);
		var constructorDeps = deps.filter(d -> !d.isThis && !d.isConstraint);

		var constructorArgs:Array<Expr> = [for (d in constructorDeps) {
			var name = d.name;
			macro $i{name};
		}];

		var params = cl.params;
		var pack = cl.pack;
		var name = cl.name;
		var classParams = cl.params.map( p -> TPType(TPath({ name : p.name, pack : []})));
		var tp:TypePath = { pack: pack, name: name, params: classParams};


		var isFallback = cl.meta.has(":fallback");

		var fallbackMeta = isFallback ? [{ name : ":fallback", pos : C.currentPos() }] : [];

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
					meta: [{ name : ":implicit", pos : C.currentPos() }].concat(fallbackMeta),
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
					access: [AStatic ].concat(doLazy ? [] : [AFinal]),
					name: "instance1",
					kind: FieldType.FVar(null, doLazy ? macro @:pos(C.currentPos()) null : expr),
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
					meta: [{ name : ":pure", pos : C.currentPos() }, { name : ":implicit", pos : C.currentPos() }].concat(fallbackMeta),
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
					meta: [{ name : ":pure", pos : C.currentPos() }, { name : ":implicit", pos : C.currentPos() }].concat(fallbackMeta),
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

	static function addImplicitly(fields:Array<Field>) {
		function isUnderscore (e:Null<Expr>) {
			return e != null && ET.toString(e) == "_";
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
				case FieldType.FVar(t, e) if (t != null && isUnderscore(e)):
					var e = macro @:pos(C.currentPos()) (scuts.implicit.Implicit.fromExpectedType():$t);

					var kind = FieldType.FVar(null, e);
					mkField(f, kind);
				case FieldType.FProp(get, set, t, e) if (t != null && isUnderscore(e)):
					var e = macro (scuts.implicit.Implicit.fromExpectedType():$t);

					var kind = FieldType.FProp(get, set, null, e);
					mkField(f, kind);
				case _ :
					f;
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


			var lookup = [for (f in fields) f.name => true];
			cl.meta.add(BUILD_ID, [], C.currentPos());
			var iVars1 = getInterfaceVars(cl);
			var iVars = iVars1.filter(x -> !lookup.exists(x.name));
			var res = fields.concat(iVars);
			var res = addAccessModifier(res);


			var res = addImplicitly(res);

			if (cl.name == "MonadZeroArray") {
				function getType (f:Field) {
					return switch f.kind {
						case FieldType.FVar(t, e):
							var t = t == null ? null : haxe.macro.ComplexTypeTools.toString(t);
							haxe.ds.Option.Some({ t : t, e: haxe.macro.ExprTools.toString(e)});
						case _:
							haxe.ds.Option.None;
					}
				}
				//trace(fields.map(x -> {a:x.name, b:x.access, t: getType(x)}));
				//trace(iVars1.map(x -> {a:x.name, b:x.access, t: getType(x)}));
				//trace(res.map(x -> {a:x.name, b:x.access, t: getType(x)}));
			}
			var deps = getDeps(fields.concat(iVars));
			var riskyInits = getRiskyInits(fields.concat(iVars));
			var res = removeThis(res);
			var res = res.filter(x -> !isConstraint(x));
			var constructor = if (!hasConstructor) createConstructor(deps) else [];
			var instance = createInstance(deps, cl, riskyInits);



			res.concat(instance).concat(constructor);
		} else {
			null;
		}
	}
}

#end