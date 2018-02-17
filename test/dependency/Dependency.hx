package dependency;
import scuts.syntax.ImplicitInstance;
import scuts.implicit.Implicit;
import scuts.implicit.Wildcard;

interface Show<T> {
	function show (t:T):String;
}
class IntShow implements Show<Int>{
	function new () {}
	@:implicit public static var instance:IntShow = new IntShow();
	public function show (t:Int):String {
		return Std.string(t);
	}
}
class ArrayShow<T> implements Show<Array<T>> implements ImplicitInstance {

	var showT:Show<T>;

	public function show (t:Array<T>):String {
		return "[" + t.map(showT.show).join(",") + "]";
	}
}

class Dependency {
	public static function main () {
		var x:Implicit<Show<Array<Int>>> = _;
		Expect.match(x.show([1,2]), "[1,2]");

	}
}