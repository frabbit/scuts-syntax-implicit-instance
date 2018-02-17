package prop;
import scuts.syntax.ImplicitInstance;
import scuts.implicit.Implicit;
import scuts.implicit.Wildcard;

interface Eq<T> {
	function eq (a:T, b:T):Bool;
}

interface Ord<T> {
	public var eq(default, null):Eq<T>;
}



class IntEq implements Eq<Int> implements ImplicitInstance {
	public function eq (a:Int, b:Int):Bool {
		return a == b;
	}
}

class IntOrd implements Ord<Int> implements ImplicitInstance {
	public var eq(default, null):Eq<Int>;
}

class Prop {
	public static function main () {
		var x:Implicit<Ord<Int>> = _;
		Expect.match(x.eq.eq(1, 1), true);

	}
}