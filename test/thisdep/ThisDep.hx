package thisdep;
import scuts.syntax.ImplicitInstance;
import scuts.implicit.Implicit;
import scuts.implicit.Wildcard;

interface Eq<T> {
	function eq(a:T, b:T):Bool;
}

interface Ord<T> {
	var equals:Eq<T>;
}


class OrdInt implements Ord<Int> implements Eq<Int> implements ImplicitInstance {
	var equals:Eq<Int> = this;
	function eq(a:Int, b:Int) {
		return a == b;
	}
}

class ThisDep {
	public static function main () {
		var x:Implicit<Ord<Int>> = _;
		Expect.match(x.equals.eq(1, 1), true);

	}
}