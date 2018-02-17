package either;
import scuts.syntax.ImplicitInstance;
import scuts.implicit.Implicit;
import scuts.implicit.Wildcard;

typedef E<A,B> = haxe.ds.Either<A,B>;

interface Functor<F> {
	function map <A,B>(fa:F<A>, f:A->B):F<B>;
}

interface Bind<F> {
	public var functor:Functor<F>;
	function flatMap <A,B>(fa:F<A>, f:A->F<B>):F<B>;
}

class EitherFunctor<L> implements Functor<E<L,_>> implements ImplicitInstance {

	public function map <A,B>(fa:E<L, A>, f:A->B):E<L,B> {
		return switch fa {
			case Left(l): Left(l);
			case Right(r): Right(f(r));
		}
	}
}

class EitherBind<L> implements Bind<E<L,_>> implements ImplicitInstance {
	public var functor:Functor<E<L,_>>;

	public function flatMap <A,B>(fa:E<L, A>, f:A->E<L,B>):E<L,B> {
		return switch fa {
			case Left(l): Left(l);
			case Right(r): f(r);
		}
	}
}


class EitherTest {
	public static function main () {
		var x:Implicit<Functor<E<String, _>>> = _;
		Expect.match(x.map(Right(1), y -> "" + y), Right("1"));

		var x:Implicit<Bind<E<String, _>>> = _;
		Expect.match(x.flatMap(Right(1), y -> Right("" + y)), Right("1"));
		Expect.match(x.functor.map(Right(1), y -> "" + y), Right("1"));

	}
}