package simple;
import scuts.syntax.ImplicitInstance;
import scuts.implicit.Implicit;
import scuts.implicit.Wildcard;

interface Show<T> {
	function show (t:T):String;
}
class IntShow implements Show<Int> implements ImplicitInstance {
	public function show (t:Int):String {
		return Std.string(t);
	}
}

class Simple {
	public static function main () {
		var x:Implicit<Show<Int>> = _;
		Expect.match(x.show(1), "1");

	}
}