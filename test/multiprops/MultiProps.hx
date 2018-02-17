package multiprops;
import scuts.syntax.ImplicitInstance;
import scuts.implicit.Implicit;
import scuts.implicit.Wildcard;

interface Eq<T> {
	function eq (a:T, b:T):Bool;
}

interface Show<T> {
	function show (a:T):String;
}

class IntShow implements Show<Int> implements ImplicitInstance {
	public function show (t:Int):String {
		return Std.string(t);
	}
}

class IntEq implements Eq<Int> implements ImplicitInstance {
	public function eq (a:Int, b:Int):Bool {
		return a == b;
	}
}

interface ShowAndEq<A,B> {
	public var eq(default, null):Eq<A>;
	public var show(default, null):Show<B>;
}

class ShowAndEqInt implements ShowAndEq<Int, Int> implements ImplicitInstance {
	public var eq(default, null):Eq<Int>;
	public var show(default, null):Show<Int>;
}

class MultiProps {
	public static function main () {
		var x:Implicit<ShowAndEq<Int,Int>> = _;
		Expect.match(x.eq.eq(1, 1), true);
		Expect.match(x.show.show(1), "1");

	}
}